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
    var body: some View {
        NavigationView {
            GridView()
                .navigationTitle("artwork")
        }
    }
}

struct GridView: View {
    private static let initialColumns = 3
    
    @State private var gridColumns = Array(repeating: GridItem(.flexible()), count: initialColumns)
    
    var body: some View {
        VStack {
            Text("Please choose a artwork")
                .font(.subheadline)
                .foregroundColor(.accent)
            
            ScrollView {
                LazyVGrid(columns: gridColumns) {
                    ForEach(artworks) { artwork in
                            NavigationLink(destination: ArtworkDetailView(artwork: artwork)) {
                                GridItemView(size: 150, artwork: artwork)
                            }
                    }
                }
                .padding()
            }
            
            Link("website_text", destination: URL(string: "https://coppersigned.com")!)
                .font(.headline)
                .padding()
        }
        .navigationBarTitle("Artwork Gallery")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GridItemView: View {
    let size: Double
    let artwork: Artwork
    
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            
            // ZStack mit Rahmen + Bild
            ZStack {
                // Quadratischer Rahmen
                Rectangle()
                    .stroke(.clear, lineWidth: 2)
                    .background(.copperBackground)
                
                // Bild selbst
                Image(artwork.name)
                    .resizable()
                    .scaledToFit()
                    .padding(4) // Rand zwischen Bild und Rahmen
            }.aspectRatio(1, contentMode: .fit)
            
            Text(artwork.name)
                .foregroundColor(.primary)
                .font(.caption2)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .allowsTightening(true)
            
            Text("\(Int(artwork.width)) x \(Int(artwork.height)) cm")
                .font(.caption2)
                
            
            Spacer()
        }
        .padding(.vertical, 10)
    }
}

struct ArtworkDetailView: View {
    let artwork: Artwork
    @State private var showARView = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(artwork.name)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .padding()
            
            Text("\(Int(artwork.width)) x \(Int(artwork.height)) cm")
                .foregroundColor(.accentColor)
                .font(.subheadline)
            
            // URL-Link mit Icon darunter
            if let url = URL(string: artwork.url) {
                Link(destination: url) {
                    Label("visit_artwork_link", systemImage: "link")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
            
            Spacer()
            
            NavigationLink(destination: WallPlacerView(selectedArtwork: artwork)) {
                Text("view_in_room")
                    .font(.headline)
                    .foregroundColor(Color.accentColor)
                    .padding()
                    .background(.white)
                    .cornerRadius(8)
                    .padding()
            }
        }
        .navigationTitle(artwork.name)
    }
}

struct WallPlacerView: View {
    @State private var showSettings = false
    @State private var showLiDARAlert = false
    @State private var showFallbackMessage = false
    @State private var showInstructionOverlay = true
    @ObservedObject private var arManager = ARManager()
    
    var selectedArtwork: Artwork
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ARViewContainer(
                selectedArtwork: .constant(selectedArtwork),
                arManager: arManager,
                showLiDARAlert: $showLiDARAlert,
                showFallbackMessage: $showFallbackMessage
            )
            .edgesIgnoringSafeArea(.all)
            .disabled(showInstructionOverlay)
            .alert(isPresented: $showLiDARAlert) {
                Alert(
                    title: Text("hint"),
                    message: Text("lidar_hint"),
                    dismissButton: .default(Text("OK"))
                )
            }
            
            // Anweisungsoverlay
            if showInstructionOverlay {
                VStack(spacing: 20) {
                    Image("Instruction") // Dein ImageSet Name
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150) // Anpassen nach Bedarf
                    
                    Text("use_hint")
                        .font(.footnote)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 20) {
                        Spacer()
                        Button("hide_hint") {
                            showInstructionOverlay = false
                        }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
                .padding()
                .onTapGesture {
                    showInstructionOverlay = false
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Fallback-Nachricht nur anzeigen, wenn LiDAR verfügbar ist und der Fallback aktiv wird
            if !deviceHasLiDAR() && showFallbackMessage {
                Text("error_hint")
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color("AccentColor"))
                    .cornerRadius(8)
                    .padding([.bottom, .trailing], 20)
            }
        }
        .navigationTitle("ar_view")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        showInstructionOverlay = true
                    }) {
                        Image(systemName: "info.circle")
                    }
                    Button(action: {
                        arManager.rotateArtwork()
                    }) {
                        Image(systemName: "rotate.right")
                    }
                }
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

struct Artwork: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let width: CGFloat // in Zentimetern
    let height: CGFloat // in Zentimetern
    let url: String
}

func getArtworkURL(artworkId: Int) -> String {
    let currentLanguage = Locale.current.language.languageCode?.identifier
    if currentLanguage == "de" {
        return "https://coppersigned.com/de/#artwork-" + String(artworkId);
    } else {
        return "https://coppersigned.com/#artwork-" + String(artworkId);
    }
}

let artworks = [
    Artwork(name: "Dancing Molecules", width: 80, height: 60, url: getArtworkURL(artworkId: 922)),
    Artwork(name: "Mermade Home", width: 100, height: 80, url: getArtworkURL(artworkId: 907)),
    Artwork(name: "Self Blooming", width: 40, height: 120, url: getArtworkURL(artworkId: 796)),
    Artwork(name: "Fire", width: 40, height: 120, url: getArtworkURL(artworkId: 785)),
    Artwork(name: "Sleeping Muse", width: 120, height: 40, url: getArtworkURL(artworkId: 756)),
    Artwork(name: "Magic Lamp", width: 110, height: 80, url: getArtworkURL(artworkId: 786)),
    Artwork(name: "Golden waves", width: 40, height: 120, url: getArtworkURL(artworkId: 396)),
    Artwork(name: "Gilded Fold", width: 50, height: 50, url: getArtworkURL(artworkId: 793)),
    Artwork(name: "Blue Lagoon", width: 40, height: 60, url: getArtworkURL(artworkId: 835)),
    Artwork(name: "Pacific", width: 50, height: 50, url: getArtworkURL(artworkId: 830)),
]

#Preview {
    //ContentView()
}
