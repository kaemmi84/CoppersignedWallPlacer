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


struct ContentView: View {
    @State private var showSettings = false
    @State private var selectedArtwork: Artwork? = artworks.first(where: {aw in aw.name == "Cyclone"})
    @StateObject private var arManager = ARManager()
    
    var body: some View {
        ZStack {
            // ARViewContainer nimmt den gesamten Hintergrund ein
            ARViewContainer(selectedArtwork: $selectedArtwork, arManager: arManager)
                .edgesIgnoringSafeArea(.all)
            
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
                        print("Zahnrad-Button wurde gedrückt")
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
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var selectedArtwork: Artwork?
    @ObservedObject var arManager: ARManager
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // AR-Session konfigurieren
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical]
        arView.session.run(configuration)
        
        // Tap-Geste hinzufügen
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        arView.addGestureRecognizer(tapGesture)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(selectedArtwork: $selectedArtwork, arManager: arManager)
    }
    
    class Coordinator: NSObject {
        @Binding var selectedArtwork: Artwork?
        var currentAnchor: AnchorEntity?
        var cancellables: Set<AnyCancellable> = []
        
        init(selectedArtwork: Binding<Artwork?>, arManager: ARManager) {
            _selectedArtwork = selectedArtwork
            super.init()
            
            // Abonnieren des Rotate-Events
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
                print("Kein Kunstwerk ausgewählt")
                return
            }
            
            // Raycast durchführen
            if let result = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .vertical).first {
                
                // Vorheriges Anker-Entity entfernen, falls vorhanden
                if let existingAnchor = currentAnchor {
                    arView.scene.removeAnchor(existingAnchor)
                    currentAnchor = nil
                }
                
                // Anker erstellen
                let anchor = AnchorEntity(world: result.worldTransform)
                
                var material = UnlitMaterial()
                // Bild als Texturressource laden
                do {
                    let texture = try TextureResource.load(named: artwork.name)
                    
                    // UnlitMaterial mit der geladenen Textur erstellen
                    
                    material.color = .init(tint: .white, texture: .init(texture))
                    
                    // Blending-Modus auf transparent setzen, um Transparenz zu unterstützen
                    material.blending = .transparent(opacity: .init(scale: 1.0))
                    
                } catch {
                    print("Fehler beim Laden der Textur: \(error)")
                }
                
                // Maße von Zentimetern in Meter umrechnen
                let widthInMeters: Float = Float(artwork.width) / 100
                let heightInMeters: Float = Float(artwork.height) / 100
                
                // Plane mit Bild erstellen
                let plane = ModelEntity(mesh: .generatePlane(width: Float(widthInMeters), height: Float(heightInMeters)), materials: [material])
                
                
                // Plane rotieren, um korrekt an der Wand auszurichten
                plane.transform.rotation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
                
                // Plane zum Anker hinzufügen
                anchor.addChild(plane)
                
                // Anker zur Szene hinzufügen
                arView.scene.addAnchor(anchor)
                
                
                // Aktuelles Anker-Entity aktualisieren
                currentAnchor = anchor
            }
        }
        
        func rotateArtwork() {
            guard let anchor = currentAnchor else {
                print("Kein Anker vorhanden, nichts zu drehen.")
                return
            }
            guard let plane = anchor.children.first as? ModelEntity else {
                print("Kein Plane-Entity gefunden.")
                return
            }
            
            // Aktuelle Rotation speichern
            let currentRotation = plane.transform.rotation
            
            // Neue Rotation um 90 Grad hinzufügen
            let rotation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0]) // 90 Grad um Y-Achse
            plane.transform.rotation = rotation * currentRotation
            
            print("Kunstwerk wurde um 90 Grad gedreht.")
        }
    }
}

// ARManager zur Verwaltung von AR-Aktionen
class ARManager: ObservableObject {
    // Publisher, der jedes Mal ein Ereignis sendet, wenn eine Drehung ausgelöst wird
    let rotateArtworkSubject = PassthroughSubject<Void, Never>()
    
    // Methode zum Auslösen der Drehung
    func rotateArtwork() {
        rotateArtworkSubject.send()
    }
}

struct SettingsView: View {
    // Zugriff auf die Präsentationsumgebung
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedArtwork: Artwork?
    
    var body: some View {
        NavigationView {
            VStack {
                List(artworks) { artwork in
                    HStack {
                        // Vorschaubild des Kunstwerks
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
                            // Anzeige der Maße
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
                
                // Link zu Coppersigned.com
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
    //    Artwork(name: "Mermaid Home", width: 100, height: 50),
    Artwork(name: "Jungle Fever", width: 120, height: 80),
    Artwork(name: "Self Blooming", width: 40, height: 120),
    Artwork(name: "Fire", width: 40, height: 120),
    //    Artwork(name: "Sleeping Muse", width: 100, height: 50),
    //    Artwork(name: "Beach", width: 100, height: 50),
    Artwork(name: "Magic Lamp", width: 110, height: 80),
    Artwork(name: "Golden waves", width: 40, height: 120),
    Artwork(name: "Earth", width: 120, height: 40),
    Artwork(name: "Gilded Fold", width: 50, height: 50),
    //    Artwork(name: "Blue Lagoon", width: 100, height: 50),
    //    Artwork(name: "Pacific", width: 100, height: 50),
    //    Artwork(name: "Whispering Forest", width: 100, height: 50),
    //    Artwork(name: "Northern Lite", width: 100, height: 50),
    //    Artwork(name: "Lightning", width: 100, height: 50),
    //    Artwork(name: "Sea & Sand", width: 100, height: 50),
    //    Artwork(name: "Bali", width: 100, height: 50),
    //    Artwork(name: "Kintsugi", width: 100, height: 50),
    Artwork(name: "Cyclone", width: 115, height: 80),
    //    Artwork(name: "Oxided Copper", width: 100, height: 50),
    //    Artwork(name: "Future Planet", width: 100, height: 50),
    //    Artwork(name: "Portugal Immersion", width: 100, height: 50),
    //    Artwork(name: "Unicorn", width: 100, height: 50),
    //    Artwork(name: "Wood meets Steel", width: 100, height: 50),
    //    Artwork(name: "Earthquake", width: 100, height: 50),
    //    Artwork(name: "Golden Confidence", width: 100, height: 50),
    //    Artwork(name: "Supernova", width: 100, height: 50)
]

#Preview {
    ContentView()
}
