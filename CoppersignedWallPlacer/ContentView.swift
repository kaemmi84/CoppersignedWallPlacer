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
        // Goal set to anyPlane to guide the user in detecting planes
        coachingOverlay.goal = .anyPlane
        coachingOverlay.activatesAutomatically = true
        self.addSubview(coachingOverlay)
    }
}

struct ContentView: View {
    @State private var showSettings = false
    @State private var selectedArtwork: Artwork? = artworks.first(where: {aw in aw.name == "Cyclone"})
    @StateObject private var arManager = ARManager()
    @State private var showLiDARAlert = false
    
    var body: some View {
        ZStack {
            // ARViewContainer takes up the entire background
            ARViewContainer(selectedArtwork: $selectedArtwork, arManager: arManager, showLiDARAlert: $showLiDARAlert)
                .edgesIgnoringSafeArea(.all)
                .alert(isPresented: $showLiDARAlert) {
                    // Keep UI strings in German
                    Alert(
                        title: Text("Hinweis"),
                        message: Text("Für beste Ergebnisse wird ein Gerät mit LiDAR-Sensor empfohlen."),
                        dismissButton: .default(Text("OK"))
                    )
                }
            
            // Gear button at the top right
            VStack {
                HStack {
                    Spacer()
                    
                    // Rotation button
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
                    
                    // Gear button
                    Button(action: {
                        // Action when tapping the gear button
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
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var selectedArtwork: Artwork?
    @ObservedObject var arManager: ARManager
    @Binding var showLiDARAlert: Bool
    
    func makeUIView(context: Context) -> ARView {
        let arView = CustomARView(frame: .zero)
        
        if !deviceHasLiDAR() {
            arView.setupCoachingOverlay()
            DispatchQueue.main.async {
                showLiDARAlert = true
            }
        }
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration)
        
        // Add tap gesture
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
            
            // Subscribe to the rotate event
            arManager.rotateArtworkSubject
                .sink { [weak self] in
                    self?.rotateArtwork()
                }
                .store(in: &cancellables)
        }
        
        @objc func handleTap(sender: UITapGestureRecognizer) {
            guard let arView = sender.view as? ARView else { return }
            let tapLocation = sender.location(in: arView)
            
            // Ensure that an artwork is selected
            guard let artwork = selectedArtwork else {
                print("No artwork selected")
                return
            }
            
            // 1. Try to find an existing vertical plane
            if let verticalPlane = arView.raycast(
                from: tapLocation,
                allowing: .existingPlaneGeometry,
                alignment: .vertical
            ).first {
                
                placeArtwork(arView: arView, transform: verticalPlane.worldTransform, artwork: artwork, rotateForWall: true)
                
            // 2. If no existing vertical plane found, try an estimated vertical plane
            } else if let verticalEstimate = arView.raycast(
                from: tapLocation,
                allowing: .estimatedPlane,
                alignment: .vertical
            ).first {
                
                placeArtwork(arView: arView, transform: verticalEstimate.worldTransform, artwork: artwork, rotateForWall: true)
                
            // 3. If that doesn't work either, fallback to a horizontal plane
            } else if let horizontalPlane = arView.raycast(
                from: tapLocation,
                allowing: .existingPlaneGeometry,
                alignment: .horizontal
            ).first {
                
                placeArtwork(arView: arView, transform: horizontalPlane.worldTransform, artwork: artwork, rotateForWall: false)
                
            } else {
                print("No suitable plane found. Please move the device to detect surfaces.")
            }
        }

        func placeArtwork(arView: ARView, transform: simd_float4x4, artwork: Artwork, rotateForWall: Bool) {
            // Remove the previous anchor entity if present
            if let existingAnchor = currentAnchor {
                arView.scene.removeAnchor(existingAnchor)
                currentAnchor = nil
            }
            
            // Create anchor
            let anchor = AnchorEntity(world: transform)
            
            var material = UnlitMaterial()
            // Load the image as a texture resource
            do {
                let texture = try TextureResource.load(named: artwork.name)
                
                material.color = .init(tint: .white, texture: .init(texture))
                material.blending = .transparent(opacity: .init(scale: 1.0))
                
            } catch {
                print("Error loading texture: \(error)")
            }
            
            // Convert centimeters to meters
            let widthInMeters: Float = Float(artwork.width) / 100
            let heightInMeters: Float = Float(artwork.height) / 100
            
            // Create plane with the image
            let plane = ModelEntity(
                mesh: .generatePlane(width: Float(widthInMeters), height: Float(heightInMeters)),
                materials: [material]
            )
            
            if rotateForWall {
                // For walls: set the plane upright
                plane.transform.rotation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
            } else {
                // For floor/table: no additional rotation needed
            }
            
            // Add plane to anchor
            anchor.addChild(plane)
            
            // Add anchor to the scene
            arView.scene.addAnchor(anchor)
            
            // Update current anchor entity
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
            
            // Save current rotation
            let currentRotation = plane.transform.rotation
            
            // Add a 90-degree rotation
            let rotation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0]) // 90 degrees around Y-axis
            plane.transform.rotation = rotation * currentRotation
            
            print("Artwork rotated by 90 degrees.")
        }
    }
}

// ARManager to manage AR actions
class ARManager: ObservableObject {
    // Publisher that sends an event each time a rotation is triggered
    let rotateArtworkSubject = PassthroughSubject<Void, Never>()
    
    // Method to trigger rotation
    func rotateArtwork() {
        rotateArtworkSubject.send()
    }
}

struct SettingsView: View {
    // Access to the presentation environment
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedArtwork: Artwork?
    
    var body: some View {
        NavigationView {
            VStack {
                // Keep UI elements in German
                List(artworks) { artwork in
                    HStack {
                        // Preview image of the artwork
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
                            // Display dimensions
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
                
                // Link to Coppersigned.com (UI remains in German)
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
    let width: CGFloat // in centimeters
    let height: CGFloat // in centimeters
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
