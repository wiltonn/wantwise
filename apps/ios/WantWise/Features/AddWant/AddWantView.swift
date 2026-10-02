import PhotosUI
import SwiftUI
import WantWiseCore

/// Add a Want (or edit one). Minimal questions, big targets, a picture first.
///
/// Add flow: picture (optional) → name → price → why → something similar? → how long to think → save →
/// "Let's think about this again on Friday, Oct 9."
struct AddWantView: View {
    enum Mode {
        case add
        case edit(WantEntity)
    }

    @Environment(WantStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var title = ""
    @State private var priceText = ""
    @State private var reason = ""
    @State private var similar: SimilarItemAnswer?
    @State private var wait: WaitChoice = .recommended()
    @State private var customDay = Date()
    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var imagePreview: UIImage?
    @State private var imageRemoved = false
    @State private var savedWant: Want?
    @State private var savedImageURL: URL?
    @State private var errorMessage: String?
    @FocusState private var focus: Field?

    private enum Field { case title, price, reason }

    init(mode: Mode = .add) {
        self.mode = mode
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var hasPicture: Bool {
        imageData != nil || (!imageRemoved && existingImageURL != nil)
    }

    private var existingImageURL: URL? {
        if case .edit(let entity) = mode { return store.imageURL(for: entity) }
        return nil
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasPicture
    }

    var body: some View {
        NavigationStack {
            Group {
                if let savedWant {
                    SavedConfirmationView(want: savedWant, imageURL: savedImageURL) { dismiss() }
                } else {
                    form
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(savedWant == nil ? (isEditing ? "Edit" : "Add a Want") : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if savedWant == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focus = nil }
                }
            }
            .alert("Couldn't save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationBackground(Theme.background)
        .onAppear(perform: loadForEditing)
    }

    // MARK: - Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                pictureSection

                field(label: "What is it?") {
                    TextField("e.g. Wireless headphones", text: $title)
                        .font(.wwTitle2)
                        .focused($focus, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focus = .price }
                        .accessibilityIdentifier("titleField")
                }

                field(label: "How much is it?", hint: "If you know") {
                    HStack(spacing: 6) {
                        Text(currencySymbol)
                            .font(.wwTitle2)
                            .foregroundStyle(Theme.textMuted)
                        TextField("0", text: $priceText)
                            .font(.wwTitle2)
                            .keyboardType(.decimalPad)
                            .focused($focus, equals: .price)
                            .accessibilityIdentifier("priceField")
                    }
                }

                field(label: "What makes you want this?") {
                    TextField("Because…", text: $reason, axis: .vertical)
                        .font(.wwBody)
                        .lineLimit(2...5)
                        .focused($focus, equals: .reason)
                        .accessibilityIdentifier("reasonField")
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel("Do you already have something similar?")
                    HStack(spacing: 10) {
                        ChoiceChip(title: "Yes", isSelected: similar == .yes) { toggle(.yes) }
                        ChoiceChip(title: "No", isSelected: similar == .no) { toggle(.no) }
                        ChoiceChip(title: "Not sure", isSelected: similar == .notSure) { toggle(.notSure) }
                    }
                }

                if !isEditing {
                    WaitChooser(wait: $wait, customDay: $customDay, title: "Think about it for")
                }
            }
            .padding(Theme.pagePadding)
            .padding(.bottom, 100)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button(isEditing ? "Save changes" : "Add to my list", action: save)
                .buttonStyle(.wwPrimary)
                .disabled(!canSave)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.vertical, 12)
                .background(Theme.background.opacity(0.95))
                .accessibilityIdentifier("saveWant")
        }
        .onChange(of: photoItem) { _, item in loadPhoto(item) }
    }

    private var pictureSection: some View {
        PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
            ZStack {
                if let imagePreview {
                    Image(uiImage: imagePreview)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 320)
                        .padding(12)
                } else if hasPicture, let existingImageURL {
                    WantArtwork(imageURL: existingImageURL, title: title, sourceType: .photo, style: .poster)
                        .frame(height: 320)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        Text("Add a screenshot or photo")
                            .font(.wwHeadline)
                            .foregroundStyle(Theme.text)
                        Text("So you'll recognise it later")
                            .font(.wwCaption)
                            .foregroundStyle(Theme.textMuted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 170)
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                    .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: hasPicture ? [] : [6, 6]))
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pickPicture")
        .overlay(alignment: .topTrailing) {
            if hasPicture {
                Button {
                    imageData = nil
                    imagePreview = nil
                    photoItem = nil
                    imageRemoved = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Theme.text, Color.black.opacity(0.6))
                }
                .padding(10)
                .accessibilityLabel("Remove picture")
            }
        }
    }

    private func field<Content: View>(label: String, hint: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(label)
                if let hint {
                    Text(hint).font(.wwLabel).foregroundStyle(Theme.textFaint)
                }
            }
            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(minHeight: Theme.touchTarget)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
        }
    }

    // MARK: - Actions

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currentCurrency
        return formatter.currencySymbol
    }

    private var currentCurrency: String {
        if case .edit(let entity) = mode { return entity.currency }
        return store.defaultCurrency
    }

    private func toggle(_ answer: SimilarItemAnswer) {
        similar = similar == answer ? nil : answer
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                errorMessage = "That picture couldn't be loaded."
                return
            }
            imageData = data
            imageRemoved = false
            // Preview from a downsampled copy so huge photos don't spike memory.
            let preview = (try? ImageEncoding.downsampledJPEG(data)).flatMap(UIImage.init(data:))
            imagePreview = preview
        }
    }

    private func loadForEditing() {
        guard case .edit(let entity) = mode else { return }
        let want = entity.snapshot
        title = want.title
        priceText = want.price.map { "\($0.decimalValue)" } ?? ""
        reason = want.reason ?? ""
        similar = want.similarItemAnswer
    }

    private var parsedPrice: Money? {
        Money.parse(priceText, currency: currentCurrency)
    }

    private func save() {
        do {
            switch mode {
            case .add:
                let sourceType: SourceType = imageData.flatMap(ImageEncoding.pixelSize(of:)).map {
                    SourceType.inferredForLibraryImage(width: $0.width, height: $0.height)
                } ?? .manual
                let draft = WantDraft(
                    title: title,
                    sourceType: sourceType,
                    price: parsedPrice,
                    reason: reason,
                    similarItemAnswer: similar,
                    revisitAt: store.revisitDate(for: wait)
                )
                let entity = try store.create(draft, imageData: imageData)
                savedImageURL = store.imageURL(for: entity)
                withAnimation(.easeOut(duration: 0.3)) { savedWant = entity.snapshot }
            case .edit(let entity):
                var edit = WantEdit(entity.snapshot)
                edit.title = title
                edit.price = parsedPrice
                edit.reason = reason
                edit.similarItemAnswer = similar
                try store.update(entity, with: edit)
                if imageData != nil || imageRemoved {
                    try store.setImage(imageData, for: entity)
                }
                dismiss()
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Add a name or a picture so you'll recognise it later."
        }
    }
}

/// "Think about it for: 3 days · 7 days · 30 days · Pick a date"
struct WaitChooser: View {
    @Binding var wait: WaitChoice
    @Binding var customDay: Date
    let title: String
    @Environment(WantStore.self) private var store

    private var isCustom: Bool {
        if case .custom = wait { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(WaitChoice.presets(store.policy), id: \.self) { choice in
                        ChoiceChip(title: choice.presetLabel ?? "", isSelected: wait == choice) { wait = choice }
                    }
                    ChoiceChip(title: "Pick a date", isSelected: isCustom) { wait = .custom(customDay) }
                }
            }
            if isCustom {
                DatePicker(
                    "Think again on",
                    selection: $customDay,
                    in: store.policy.earliestCustomDay(from: store.displayNow, calendar: store.calendar)...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(Theme.accent)
                .padding(8)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
                .onChange(of: customDay) { _, day in wait = .custom(day) }
            }
            Text(Formatting.thinkAgainSentence(store.revisitDate(for: wait), now: store.displayNow, calendar: store.calendar))
                .font(.wwCaption)
                .foregroundStyle(Theme.textMuted)
        }
        .onAppear {
            if customDay < store.policy.earliestCustomDay(from: store.displayNow, calendar: store.calendar) {
                customDay = store.policy.revisitDate(afterDays: 1, from: store.displayNow, calendar: store.calendar)
            }
        }
    }
}

/// The moment after saving: the picture, and when we'll think again.
struct SavedConfirmationView: View {
    let want: Want
    let imageURL: URL?
    let onDone: () -> Void
    @Environment(WantStore.self) private var store

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)
            WantArtwork(imageURL: imageURL, title: want.displayTitle, sourceType: want.sourceType, style: .poster)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
            VStack(spacing: 10) {
                Text("Added to your list")
                    .font(.wwLabel)
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.accent)
                Text(want.displayTitle)
                    .font(.wwTitle)
                    .multilineTextAlignment(.center)
                if let revisitAt = want.revisitAt {
                    Text(Formatting.thinkAgainSentence(revisitAt, now: store.displayNow, calendar: store.calendar))
                        .font(.wwTitle2)
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("thinkAgainMessage")
                }
            }
            Spacer()
            Button("Done", action: onDone)
                .buttonStyle(.wwPrimary)
                .accessibilityIdentifier("doneAfterSave")
        }
        .foregroundStyle(Theme.text)
        .padding(Theme.pagePadding)
    }
}

#if DEBUG
#Preview("Add") {
    AddWantView()
        .previewEnvironment(sample: true)
}
#endif
