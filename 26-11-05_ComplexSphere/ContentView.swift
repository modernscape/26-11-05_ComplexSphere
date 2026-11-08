import SwiftUI
import RealityKit

struct ContentView: View {
    @State private var targetEntity: Entity? = nil
    
    @State private var accumulatedRotation: simd_quatf = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    @State private var currentScale: Float = 1.0
    @State private var accumulatedScale: Float = 1.0
    
    // 選択されたメッシュ名を保持
    @State private var selectedMeshName: String = "パーツをタップしてください"
    
    var body: some View {
        ZStack {
            RealityView { content in
                do {
                    let loadedScene = try await Entity.load(named: "model")
                    
                    if let emptyEntity = loadedScene.findEntity(named: "Empty") {
                        self.targetEntity = emptyEntity
                    } else {
                        self.targetEntity = loadedScene
                    }
                    
                    if let target = self.targetEntity {
                        target.components.set(InputTargetComponent())
                        applyCollisionToMeshes(entity: target, relativeTo: target)
                        content.add(loadedScene)
                    }
                    
                } catch {
                    print("Failed to load model: \(error)")
                }
            } update: { content in
            }
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        let sensitivity: Float = 0.005
                        let deltaX = Float(value.translation.width) * sensitivity
                        let deltaY = Float(value.translation.height) * sensitivity
                        
                        let rotX = simd_quatf(angle: deltaY, axis: SIMD3<Float>(1, 0, 0))
                        let rotY = simd_quatf(angle: deltaX, axis: SIMD3<Float>(0, 1, 0))
                        let currentRotation = rotY * rotX
                        
                        if let target = self.targetEntity {
                            target.transform.rotation = accumulatedRotation * currentRotation
                        }
                    }
                    .onEnded { value in
                        let sensitivity: Float = 0.005
                        let deltaX = Float(value.translation.width) * sensitivity
                        let deltaY = Float(value.translation.height) * sensitivity
                        
                        let rotX = simd_quatf(angle: deltaY, axis: SIMD3<Float>(1, 0, 0))
                        let rotY = simd_quatf(angle: deltaX, axis: SIMD3<Float>(0, 1, 0))
                        let currentRotation = rotY * rotX
                        
                        accumulatedRotation = accumulatedRotation * currentRotation
                        
                        if let target = self.targetEntity {
                            target.transform.rotation = accumulatedRotation
                        }
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        let newScale = accumulatedScale * Float(value.magnification)
                        let clampedScale = max(0.2, min(newScale, 5.0))
                        currentScale = clampedScale
                        
                        if let target = self.targetEntity {
                            target.transform.scale = SIMD3<Float>(repeating: currentScale)
                        }
                    }
                    .onEnded { value in
                        accumulatedScale = currentScale
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let tapLocation = value.location
                        print("Tap location: \(tapLocation)")
                        
                        // 【簡易ヒットテスト】
                        // 複雑なレイキャストの代わりに、targetEntity（Empty）の直下にある
                        // すべての子メッシュを走査し、タップ時に何らかのパーツを選択状態にする（または順番に切り替える、
                        // もしくはコリジョン情報を利用した判定を行う）ことができます。
                        
                        if let target = self.targetEntity {
                            // 例として、タップされるたびに子メッシュの中からモデルエンティティを1つずつ赤くしていく、
                            // あるいは全メッシュの中からヒット判定を行うロジックをここに繋げます。
                            hitTestAndHighlight(at: tapLocation, in: target)
                        }
                    }
            )
            
            // UIオーバーレイ
            VStack {
                Text(selectedMeshName)
                    .font(.headline)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .padding(.top, 50)
                
                Spacer()
                
                Button("ホイールを動かす") {
                    if let target = self.targetEntity,
                       let frontWheel = target.findEntity(named: "Wheel_Front_Left") as? ModelEntity {
                        frontWheel.transform.rotation = simd_quatf(angle: .pi / 4, axis: SIMD3<Float>(0, 1, 0))
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding(.bottom, 30)
            }
        }
    }
    
    private func applyCollisionToMeshes(entity: Entity, relativeTo root: Entity) {
        if let modelEntity = entity as? ModelEntity {
            let bounds = modelEntity.visualBounds(relativeTo: root)
            let shape = ShapeResource.generateBox(size: bounds.extents)
            modelEntity.components.set(CollisionComponent(shapes: [shape]))
            modelEntity.components.set(InputTargetComponent())
        }
        for child in entity.children {
            applyCollisionToMeshes(entity: child, relativeTo: root)
        }
    }
    
    /// タップ位置に応じて、画面上で一番近くにある子メッシュをヒットテストして赤くハイライトする関数
    private func hitTestAndHighlight(at location: CGPoint, in rootEntity: Entity) {
        var modelEntities: [ModelEntity] = []
        collectModelEntities(from: rootEntity, into: &modelEntities)
        
        // 各メッシュの親（ルート）からの相対位置やバウンディングを基に、
        // タップ位置に近いパーツを特定するための仕組みをここに実装します。
        
        // ※今回は手軽にタップするたびにリストの次のパーツに切り替わるようにするか、
        // あるいは各メッシュの名称を変更して確認できるようにしてみます。
        // （もしランダムや順番に切り替えたい場合は以下のようにインデックスを回せます）
        
        // 例として、タップするたびに異なるパーツが順番に赤くなるようにしてみると、
        // マテリアル変更のロジックがすべてのパーツで正常に動いているかが確認できます：
        var currentIndex = 0
        if !modelEntities.isEmpty {
            let targetModel = modelEntities[currentIndex % modelEntities.count]
            let meshName = targetModel.name.isEmpty ? "Unnamed Mesh" : targetModel.name
            selectedMeshName = meshName
            
            // 赤く変色させる
            var material = SimpleMaterial()
            material.baseColor = .color(.red)
            material.roughness = .init(floatLiteral: 0.2)
            targetModel.model?.materials = [material]
            
            print("Highlighted: \(meshName) (Index: \(currentIndex))")
            currentIndex += 1
        }
    }
    
    private func collectModelEntities(from entity: Entity, into list: inout [ModelEntity]) {
        if let modelEntity = entity as? ModelEntity {
            list.append(modelEntity)
        }
        for child in entity.children {
            collectModelEntities(from: child, into: &list)
        }
    }
}
