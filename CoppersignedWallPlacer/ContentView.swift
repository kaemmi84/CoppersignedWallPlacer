//
//  ContentView.swift
//  CoppersignedWallPlacer
//
//  Created by Steffen Kämmerer on 14.11.24.
//

import SwiftUI
import RealityKit
import ARKit
import Combine

func deviceHasLiDAR() -> Bool {
    return ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
}

class CustomARView: ARView, ARCoachingOverlayViewDelegate {
    func setupCoachingOverlay() {
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.delegate = self
        coachingOverlay.session = self.session
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // Ziel auf anyPlane gesetzt, um den Nutzer bei der Erkennung von Ebenen zu unterstützen
        coachingOverlay.goal = .anyPlane
        coachingOverlay.activatesAutomatically = true
        self.addSubview(coachingOverlay)
    }
}

struct ContentView: View {
    @State private var showSettings = false
    @State private var selectedArtwork: Artwork? = artworks.first(where: { aw in aw.name == "Cyclone" })
    @StateObject private var arManager = ARManager()
    @State private var showLiDARAlert = false
    @State private var showFallbackMessage = false // Zustand für Fallback-Nachricht
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ARViewContainer(
                selectedArtwork: $selectedArtwork,
                arManager: arManager,
                showLiDARAlert: $showLiDARAlert,
                showFallbackMessage: $showFallbackMessage
            )
            .edgesIgnoringSafeArea(.all)
            .alert(isPresented: $showLiDARAlert) {
                // UI Strings bleiben auf Deutsch
                Alert(
                    title: Text("Hinweis"),
                    message: Text("Für beste Ergebnisse wird ein Gerät mit LiDAR-Sensor empfohlen."),
                    dismissButton: .default(Text("OK"))
                )
            }
            
            // Zahnrad-Button oben rechts
            VStack {
                HStack {
                    Spacer()
                    
                    // Rotations-Button
                    Button(action: {
                        arManager.rotateArtwork()
                    }) {
                        Image(systemName: "rotate.right")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .padding()
                            .background(Color.white.opacity(0.7))
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .tint(Color("AccentColor"))
                    .padding([.top, .trailing], 20)
                    
                    // Zahnrad-Button
                    Button(action: {
                        // Aktion beim Tippen auf den Zahnrad-Button
                        print("Gear button pressed")
                        showSettings.toggle()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .padding()
                            .background(Color.white.opacity(0.7))
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .tint(Color("AccentColor"))
                    .padding([.top, .trailing], 20)
                    .sheet(isPresented: $showSettings) {
                        SettingsView(selectedArtwork: $selectedArtwork)
                    }
                }
                Spacer()
            }
            
            // Fallback-Nachricht nur anzeigen, wenn LiDAR verfügbar ist und der Fallback aktiv wird
            if !deviceHasLiDAR() && showFallbackMessage {
                Text("Keine geeignete Oberfläche gefunden.\nBitte bewege dich langsam, um Ebenen zu erkennen.\nTexturierte Oberflächen werden besser erkannt.")
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color("AccentColor"))
                    .cornerRadius(8)
                    .padding([.bottom, .trailing], 20)
            }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var selectedArtwork: Artwork?
    @ObservedObject var arManager: ARManager
    @Binding var showLiDARAlert: Bool
    @Binding var showFallbackMessage: Bool
    
    func makeUIView(context: Context) -> ARView {
        let arView = CustomARView(frame: .zero)
        
        if !deviceHasLiDAR() {
            // Kein LiDAR: Coaching Overlay anzeigen und Hinweis
            arView.setupCoachingOverlay()
            DispatchQueue.main.async {
                showLiDARAlert = true
            }
        }
        
        // AR-Session konfigurieren
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = deviceHasLiDAR() ? [.horizontal, .vertical] : [.vertical]
        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)
        
        // Tap-Geste hinzufügen
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        arView.addGestureRecognizer(tapGesture)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(selectedArtwork: $selectedArtwork, arManager: arManager, showFallbackMessage: $showFallbackMessage)
    }
    
    class Coordinator: NSObject {
        @Binding var selectedArtwork: Artwork?
        @Binding var showFallbackMessage: Bool
        var currentAnchor: AnchorEntity?
        var cancellables: Set<AnyCancellable> = []
        let arManager: ARManager
        
        init(selectedArtwork: Binding<Artwork?>, arManager: ARManager, showFallbackMessage: Binding<Bool>) {
            _selectedArtwork = selectedArtwork
            _showFallbackMessage = showFallbackMessage
            self.arManager = arManager
            super.init()
            
            // Rotate-Event abonnieren
            arManager.rotateArtworkSubject
                .sink { [weak self] in
                    self?.rotateArtwork()
                }
                .store(in: &cancellables)
        }
        
        @objc func handleTap(sender: UITapGestureRecognizer) {
            guard let arView = sender.view as? ARView else { return }
            let tapLocation = sender.location(in: arView)
            
            // Sicherstellen, dass ein Kunstwerk ausgewählt ist
            guard let artwork = selectedArtwork else {
                print("No artwork selected")
                return
            }
            
            if !deviceHasLiDAR() {
                // Mit LiDAR: vertikal -> geschätzt vertikal -> horizontal
                if let verticalPlane = arView.raycast(
                    from: tapLocation,
                    allowing: .existingPlaneGeometry,
                    alignment: .vertical
                ).first {
                    DispatchQueue.main.async {
                        self.showFallbackMessage = false
                    }
                    placeArtwork(arView: arView, transform: verticalPlane.worldTransform, artwork: artwork, rotateForWall: true)
                    
                } else if let verticalEstimate = arView.raycast(
                    from: tapLocation,
                    allowing: .estimatedPlane,
                    alignment: .vertical
                ).first {
                    
                    showFallbackMessage = false
                    placeArtwork(arView: arView, transform: verticalEstimate.worldTransform, artwork: artwork, rotateForWall: true)
                    
                } else if let horizontalPlane = arView.raycast(
                    from: tapLocation,
                    allowing: .existingPlaneGeometry,
                    alignment: .horizontal
                ).first {
                    DispatchQueue.main.async {
                        self.showFallbackMessage = false
                    }
                    placeArtwork(arView: arView, transform: horizontalPlane.worldTransform, artwork: artwork, rotateForWall: false)
                    
                } else {
                    print("No suitable plane found. Please move the device to detect surfaces.")
                    DispatchQueue.main.async {
                        self.showFallbackMessage = true
                    }
                }
                
            } else {
                // Ohne LiDAR: nur vertikal (wie ursprünglich)
                if let verticalPlane = arView.raycast(
                    from: tapLocation,
                    allowing: .existingPlaneGeometry,
                    alignment: .vertical
                ).first {
                    placeArtwork(arView: arView, transform: verticalPlane.worldTransform, artwork: artwork, rotateForWall: true)
                } else {
                    print("No suitable vertical plane found")
                    DispatchQueue.main.async {
                        self.showFallbackMessage = false
                    }
                }
            }
        }

        func placeArtwork(arView: ARView, transform: simd_float4x4, artwork: Artwork, rotateForWall: Bool) {
            // Vorheriges Anker-Entity entfernen, falls vorhanden
            if let existingAnchor = currentAnchor {
                arView.scene.removeAnchor(existingAnchor)
                currentAnchor = nil
            }
            
            // Anker erstellen
            let anchor = AnchorEntity(world: transform)
            
            var material = UnlitMaterial()
            // Bild als Texturressource laden
            do {
                let texture = try TextureResource.load(named: artwork.name)
                material.color = .init(tint: .white, texture: .init(texture))
                material.blending = .transparent(opacity: .init(scale: 1.0))
            } catch {
                print("Error loading texture: \(error)")
            }
            
            // Maße umrechnen
            let widthInMeters: Float = Float(artwork.width) / 100
            let heightInMeters: Float = Float(artwork.height) / 100
            
            // Plane mit Bild erstellen
            let plane = ModelEntity(
                mesh: .generatePlane(width: Float(widthInMeters), height: Float(heightInMeters)),
                materials: [material]
            )
            
            if rotateForWall {
                // Für Wände aufrichten
                plane.transform.rotation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
            } else {
                // Für Boden/Tisch: keine zusätzliche Rotation
            }
            
            // Plane zum Anker hinzufügen
            anchor.addChild(plane)
            
            // Anker zur Szene hinzufügen
            arView.scene.addAnchor(anchor)
            
            // Aktuelles Anker-Entity aktualisieren
            currentAnchor = anchor
        }
        
        func rotateArtwork() {
            guard let anchor = currentAnchor else {
                print("No anchor present, nothing to rotate.")
                return
            }
            guard let plane = anchor.children.first as? ModelEntity else {
                print("No plane entity found.")
                return
            }
            
            let currentRotation = plane.transform.rotation
            let rotation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
            plane.transform.rotation = rotation * currentRotation
            print("Artwork rotated by 90 degrees.")
        }
    }
}

// ARManager zur Verwaltung von AR-Aktionen
class ARManager: ObservableObject {
    let rotateArtworkSubject = PassthroughSubject<Void, Never>()
    
    func rotateArtwork() {
        rotateArtworkSubject.send()
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedArtwork: Artwork?
    
    var body: some View {
        NavigationView {
            VStack {
                // UI auf Deutsch belassen
                List(artworks) { artwork in
                    HStack {
                        Image(artwork.name)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            .padding(.trailing, 8)
                        
                        VStack(alignment: .leading) {
                            Text(artwork.name)
                                .font(.headline)
                                .foregroundColor(selectedArtwork == artwork ? .white : .primary)
                            Text("\(String(format: "%.0f", artwork.width))cm x \(String(format: "%.0f", artwork.height))cm")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .background(selectedArtwork == artwork ? Color("AccentColor") : Color.clear)
                    .cornerRadius(8)
                    .onTapGesture {
                        selectedArtwork = artwork
                        dismiss()
                    }
                }
                .listStyle(PlainListStyle())
                
                Link("Besuchen Sie Coppersigned.com", destination: URL(string: "https://coppersigned.com")!)
                    .font(.headline)
                    .padding()
            }
            .navigationTitle("Wähle ein Kunstwerk")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct Artwork: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let width: CGFloat // in Zentimetern
    let height: CGFloat // in Zentimetern
}

let artworks = [
    Artwork(name: "Jungle Fever", width: 120, height: 80),
    Artwork(name: "Self Blooming", width: 40, height: 120),
    Artwork(name: "Fire", width: 40, height: 120),
    Artwork(name: "Magic Lamp", width: 110, height: 80),
    Artwork(name: "Golden waves", width: 40, height: 120),
    Artwork(name: "Earth", width: 120, height: 40),
    Artwork(name: "Gilded Fold", width: 50, height: 50),
    Artwork(name: "Cyclone", width: 115, height: 80),
]

#Preview {
    ContentView()
}
