import SwiftUI
import SwiftData
import PhotosUI

struct QSOEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let qso: QSO

    @State private var potaRef = ""
    @State private var sotaRef = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("QSO") {
                    LabeledContent("Call", value: qso.call)
                    LabeledContent("Date", value: qso.qsoDate)
                    if let time = qso.timeOn { LabeledContent("Time", value: time) }
                    if let band = qso.band { LabeledContent("Band", value: band) }
                    if let mode = qso.mode { LabeledContent("Mode", value: mode) }
                    if let freq = qso.freq { LabeledContent("Freq", value: freq) }
                }

                Section("Activation Refs") {
                    TextField("POTA Reference", text: $potaRef)
                        .autocapitalization(.allCharacters)
                    TextField("SOTA Reference", text: $sotaRef)
                        .autocapitalization(.allCharacters)
                }

                Section("Photo") {
                    if let data = imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 240)
                    }
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(imageData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                    }
                    if imageData != nil {
                        Button("Remove Photo", role: .destructive) {
                            imageData = nil
                        }
                    }
                }
            }
            .navigationTitle(qso.call)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear {
                potaRef = qso.potaRef ?? ""
                sotaRef = qso.sotaRef ?? ""
                imageData = qso.imageData
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        imageData = data
                    }
                }
            }
        }
    }

    private func save() {
        qso.potaRef = potaRef.uppercased().isEmpty ? nil : potaRef.uppercased()
        qso.sotaRef = sotaRef.uppercased().isEmpty ? nil : sotaRef.uppercased()
        qso.imageData = imageData
        try? context.save()
        dismiss()
    }
}
