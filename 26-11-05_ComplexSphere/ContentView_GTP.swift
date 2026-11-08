
import SwiftUI
import RealityKit
import simd

struct ContentView__: View {
    
    @State private var modelRoot: Entity?
    @State private var selectedMesh: String?
    
    @State private var dragStartRotation = simd_quatf(
        angle: 0,
        axis: SIMD3<Float>(0, 1, 0)
    )
    
    @State private var isDragging = false
    @State private var errorMessage: String?
    
    var body: some View {
        
        ZStack(alignment: .bottom) {
            
            RealityView { content in
                
                do {
                    let entity = try await Entity(
                        named: "model.usdc"
                    )
                    
                    setupInteraction(entity)
                    
                    modelRoot = entity
                    content.add(entity)
                    
                } catch {
                    errorMessage = error.localizedDescription
                }
                
            } update: { content in
                
                // モデル更新
            }
            
            // ドラッグによるモデル回転
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        
                        guard let modelRoot else { return }
                        
                        if !isDragging {
                            dragStartRotation = modelRoot.orientation
                            isDragging = true
                        }
                        
                        let horizontal = simd_quatf(
                            angle: Float(value.translation.width) * 0.01,
                            axis: SIMD3<Float>(0, 1, 0)
                        )
                        
                        let vertical = simd_quatf(
                            angle: Float(value.translation.height) * 0.01,
                            axis: SIMD3<Float>(1, 0, 0)
                        )
                        
                        modelRoot.orientation =
                        horizontal * vertical * dragStartRotation
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            
            // メッシュのタップ
            .simultaneousGesture(
                TapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        handleMeshTap(value.entity)
                    }
            )
            
            // SwiftUI UI
            VStack(spacing: 12) {
                
                if let selectedMesh {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        
                        Text("Selected Mesh")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(selectedMesh)
                            .font(.title2)
                            .bold()
                        
                        Text("このメッシュが選択されました。")
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                } else {
                    
                    Text("メッシュをタップしてください")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
            .padding()
        }
        .background(Color.black)
        .alert(
            "読み込みエラー",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    // MARK: - Setup Interaction
    
    private func setupInteraction(_ entity: Entity) {
        
        entity.generateCollisionShapes(recursive: true)
        
        setupInputTarget(entity)
    }
    
    private func setupInputTarget(_ entity: Entity) {
        
        if entity.components[ModelComponent.self] != nil {
            entity.components.set(InputTargetComponent())
        }
        
        for child in entity.children {
            setupInputTarget(child)
        }
    }
    
    // MARK: - Mesh Tap Event
    
    private func handleMeshTap(_ entity: Entity) {
        
        selectedMesh = entity.name
        
        guard let modelEntity = entity as? ModelEntity,
              var modelComponent = modelEntity.components[
                ModelComponent.self
              ] else {
            return
        }
        
        let highlightMaterial = SimpleMaterial(
            color: .cyan,
            roughness: 0.2,
            isMetallic: true
        )
        
        modelComponent.materials = [highlightMaterial]
        
        modelEntity.components.set(modelComponent)
    }
}
