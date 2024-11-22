//
//  ContentView.swift
//  CoppersignedWallPlacer
//
//  Created by Steffen Kämmerer on 14.11.24.
//

import SwiftUI
import RealityKit
import ARKit


struct ContentView: View {
    var body: some View {
        ARViewContainer()
            .edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
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
        Coordinator()
    }
    
    class Coordinator: NSObject {
        // Eigenschaft zum Speichern des aktuellen Ankers
        var currentAnchor: AnchorEntity?
        
        @objc func handleTap(sender: UITapGestureRecognizer) {
            guard let arView = sender.view as? ARView else { return }
            let tapLocation = sender.location(in: arView)
            
            // Raycast durchführen
            if let result = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .vertical).first {
                
                // Vorheriges Anker-Entity entfernen, falls vorhanden
                if let existingAnchor = currentAnchor {
                    arView.scene.removeAnchor(existingAnchor)
                    currentAnchor = nil
                }
                
                // Anker erstellen
                let anchor = AnchorEntity(world: result.worldTransform)
                
                // Bild als Material laden
                var material = UnlitMaterial()
                material.color = try! .init(tint: .white, texture: .init(.load(named: "Cyclone")))
                
                // Maße von Zentimetern in Meter umrechnen
                let widthInMeters: Float = 115 / 100
                let heightInMeters: Float = 80 / 100
                
                // Plane mit Bild erstellen
                let plane = ModelEntity(mesh: .generatePlane(width: Float(widthInMeters), height: Float(heightInMeters)), materials: [material])
                                
                
                // Plane mit Bild erstellen
//                let plane = ModelEntity(mesh: .generatePlane(width: 0.5, height: 0.5), materials: [material])
                plane.transform.rotation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
                
                // Plane zum Anker hinzufügen
                anchor.addChild(plane)
                
                // Anker zur Szene hinzufügen
                arView.scene.addAnchor(anchor)
                
                
                // Aktuelles Anker-Entity aktualisieren
                currentAnchor = anchor
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
//    Artwork(name: "Jungle Fever", width: 100, height: 50),
//    Artwork(name: "Self Blooming", width: 100, height: 50),
//    Artwork(name: "Fire", width: 120, height: 40),
//    Artwork(name: "Sleeping Muse", width: 100, height: 50),
//    Artwork(name: "Beach", width: 100, height: 50),
//    Artwork(name: "Magic Lamp", width: 120, height: 40),
//    Artwork(name: "Golden Waves", width: 100, height: 50),
//    Artwork(name: "Earth", width: 100, height: 50),
//    Artwork(name: "Gilded Fold", width: 100, height: 50),
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
