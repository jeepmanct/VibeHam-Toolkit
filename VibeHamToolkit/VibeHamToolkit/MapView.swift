import SwiftUI
import SwiftData
import MapKit

struct MapView: View {
    @Query private var qsos: [QSO]
    @State private var position: MapCameraPosition = .automatic

    private var annotations: [QSOAnnotation] {
        qsos.compactMap { qso in
            guard let grid = qso.gridsquare, !grid.isEmpty,
                  let coord = GridUtility.coordinate(from: grid) else { return nil }
            return QSOAnnotation(qso: qso, coordinate: coord)
        }
    }

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                ForEach(annotations) { annotation in
                    Annotation(annotation.qso.call, coordinate: annotation.coordinate) {
                        Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .mapStyle(.standard)
            .navigationTitle("QSO Map")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fit") {
                        if annotations.isEmpty { return }
                        let rect = annotations.reduce(MKMapRect.null) { rect, ann in
                            let point = MKMapPoint(ann.coordinate)
                            return rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
                        }
                        withAnimation {
                            position = .rect(rect)
                        }
                    }
                }
            }
        }
    }
}

struct QSOAnnotation: Identifiable {
    let id = UUID()
    let qso: QSO
    let coordinate: CLLocationCoordinate2D
}

#Preview {
    MapView()
        .modelContainer(for: [QSO.self], inMemory: true)
}
