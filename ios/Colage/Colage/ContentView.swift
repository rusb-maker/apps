//
//  ContentView.swift
//  Colage
//
//  Created by Ruslan on 2025-09-10.
//

import SwiftUI
import AVKit
import UniformTypeIdentifiers

#if canImport(UIKit)
import PhotosUI
import UIKit
import CoreImage

// MARK: - Picked media type (image or video)
enum PickedMedia {
    case image(UIImage)
    case video(URL)
}

// MARK: - Liquid slider (iOS 26-style pill slider)
struct LiquidSlider: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let step: CGFloat
    let resetValue: CGFloat

    private func snapped(_ raw: CGFloat) -> CGFloat {
        let stepped = (raw / step).rounded() * step
        return max(range.lowerBound, min(range.upperBound, stepped))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.primary.opacity(0.12))
                    .frame(width: max(fraction * w, 0))
                    .animation(.interactiveSpring(duration: 0.1), value: value)
                HStack(spacing: 0) {
                    Text(label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(value.truncatingRemainder(dividingBy: 1) == 0
                         ? "\(Int(value))"
                         : String(format: "%.1f", value))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Button {
                        value = resetValue
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 10)
                }
                .padding(.horizontal, 16)
            }
            .frame(width: w, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let frac = max(0, min(1, drag.location.x / w))
                        let new = snapped(range.lowerBound + frac * (range.upperBound - range.lowerBound))
                        if new != value {
                            value = new
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                    }
                    .onEnded { _ in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            )
        }
        .frame(height: 56)
    }
}

// MARK: - Glass button style
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.45), .white.opacity(0.1)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - iOS Content
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    // MARK: Templates & styles
    enum Template: String, CaseIterable, Identifiable {
        case twoHorizontal = "2: Horizontal"
        case twoVertical = "2: Vertical"
        case threeOneTopTwoBottom = "3: 1 top, 2 bottom"
        case threeTwoTopOneBottom = "3: 2 top, 1 bottom"
        case threeOneLeftTwoRight = "3: 1 left, 2 right"
        case threeTwoLeftOneRight = "3: 2 left, 1 right"
        case fourGrid = "4: 2×2"
        case fiveTopGridBottomBig = "5: 2×2 top, 1 bottom big"
        case sixGrid = "6: 3×2 grid"
        case sixTwoPerRow = "6: 2×3 grid"
        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .twoHorizontal:          return "2 Side by Side"
            case .twoVertical:            return "2 Stacked"
            case .threeOneTopTwoBottom:   return "1 + 2 Bottom"
            case .threeTwoTopOneBottom:   return "2 Top + 1"
            case .threeOneLeftTwoRight:   return "1 + 2 Right"
            case .threeTwoLeftOneRight:   return "2 Left + 1"
            case .fourGrid:               return "4 Grid"
            case .fiveTopGridBottomBig:   return "4 + 1 Big"
            case .sixGrid:               return "6 Wide Grid"
            case .sixTwoPerRow:          return "6 Tall Grid"
            }
        }
    }

    private func pauseAllVideos() {
        [video1, video2, video3, video4, video5, video6].forEach { $0?.pause() }
    }

    private func resumeAllVideos() {
        [video1, video2, video3, video4, video5, video6].forEach { $0?.play() }
    }

    enum BorderStyle: String, CaseIterable, Identifiable {
        case separators = "Separators"
        var id: String { rawValue }

        var defaultSpacing: CGFloat { 4 }
    }

    // MARK: State
    @State private var selectedTemplate: Template = .twoHorizontal
    @State private var borderStyle: BorderStyle = .separators

    @State private var item1: PhotosPickerItem?
    @State private var item2: PhotosPickerItem?
    @State private var item3: PhotosPickerItem?
    @State private var item4: PhotosPickerItem?
    @State private var image1: UIImage?
    @State private var image2: UIImage?
    @State private var image3: UIImage?
    @State private var image4: UIImage?
    @State private var image5: UIImage?
    @State private var image6: UIImage?
    // Video players per pane (nil if pane holds an image)
    @State private var video1: AVPlayer?
    @State private var video2: AVPlayer?
    @State private var video3: AVPlayer?
    @State private var video4: AVPlayer?
    @State private var video5: AVPlayer?
    @State private var video6: AVPlayer?
    // Video URLs (for export)
    @State private var videoURL1: URL?
    @State private var videoURL2: URL?
    @State private var videoURL3: URL?
    @State private var videoURL4: URL?
    @State private var videoURL5: URL?
    @State private var videoURL6: URL?

    @State private var showTemplatePicker: Bool = true
    @State private var renderedImage: UIImage?
    @State private var saveToast: String? = nil
    @State private var showVideoLimitAlert: Bool = false
    @State private var isExportingVideo: Bool = false
    @State private var exportProgress: Double = 0
    @State private var cancelExport: Bool = false
    // In-pane picking state
    @State private var activePaneIndex: Int? = nil
    @State private var showingSystemPhotoPicker: Bool = false
    // Per-pane transform state (scale + offset), persisted for export
    @State private var paneScales: [CGFloat] = [1, 1, 1, 1, 1, 1]
    @State private var paneOffsets: [CGSize] = Array(repeating: .zero, count: 6)
    // Unified border
    @State private var borderGap: CGFloat = 4
    @State private var borderColor: Color = .black
    @State private var borderRadius: CGFloat = 16
    @State private var hidePaneFrame: Bool = false
    // Border settings sheet
    @State private var showBorderSettings: Bool = false
    @State private var borderPanelHeight: CGFloat = 0
    @State private var borderPanelDrag: CGFloat = 0
    // Current canvas aspect ratio (width/height)
    @State private var canvasAspect: CGFloat = 1.0


    var body: some View {
        NavigationStack {
            mainContent
            .navigationTitle("Collage")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button("Reset") { resetCollageMedia() }
                        .buttonStyle(GlassButtonStyle())
                        .onChange(of: scenePhase) { _, newPhase in
                            switch newPhase {
                            case .active: resumeAllVideos()
                            case .inactive, .background: pauseAllVideos()
                            @unknown default: pauseAllVideos()
                            }
                        }
                    Button("Templates") { showTemplatePicker = true }
                        .buttonStyle(GlassButtonStyle())
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Save") { saveTapped() }
                        .buttonStyle(GlassButtonStyle())
                }
            }
            .sheet(isPresented: $showTemplatePicker) {
                TemplatePickerView(selected: $selectedTemplate, isPresented: $showTemplatePicker)
            }
            // Removed sheet; panel is inline now
            .alert("Video limit reached", isPresented: $showVideoLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You can add up to 4 videos to a collage.")
            }
            .fullScreenCover(isPresented: $showingSystemPhotoPicker) {
                SystemPhotoPicker { picked in
                    func setPane(index: Int, media: PickedMedia?) {
                        if case .video(_)? = media {
                            let urls: [URL?] = [videoURL1, videoURL2, videoURL3, videoURL4, videoURL5, videoURL6]
                            let currentPaneHasVideo = urls[index - 1] != nil
                            let currentCount = urls.compactMap { $0 }.count
                            if !currentPaneHasVideo && currentCount >= 4 {
                                showVideoLimitAlert = true
                                return
                            }
                        }
                        switch (index, media) {
                        case (1, .image(let img)?): video1?.pause(); video1 = nil; videoURL1 = nil; image1 = img
                        case (2, .image(let img)?): video2?.pause(); video2 = nil; videoURL2 = nil; image2 = img
                        case (3, .image(let img)?): video3?.pause(); video3 = nil; videoURL3 = nil; image3 = img
                        case (4, .image(let img)?): video4?.pause(); video4 = nil; videoURL4 = nil; image4 = img
                        case (5, .image(let img)?): video5?.pause(); video5 = nil; videoURL5 = nil; image5 = img
                        case (6, .image(let img)?): video6?.pause(); video6 = nil; videoURL6 = nil; image6 = img
                        case (1, .video(let url)?):
                            video1?.pause(); video1 = nil
                            let pitem1 = AVPlayerItem(url: url); pitem1.preferredForwardBufferDuration = 2
                            video1 = AVPlayer(playerItem: pitem1); video1?.isMuted = true; image1 = nil; videoURL1 = url
                        case (2, .video(let url)?):
                            video2?.pause(); video2 = nil
                            let pitem2 = AVPlayerItem(url: url); pitem2.preferredForwardBufferDuration = 2
                            video2 = AVPlayer(playerItem: pitem2); video2?.isMuted = true; image2 = nil; videoURL2 = url
                        case (3, .video(let url)?):
                            video3?.pause(); video3 = nil
                            let pitem3 = AVPlayerItem(url: url); pitem3.preferredForwardBufferDuration = 2
                            video3 = AVPlayer(playerItem: pitem3); video3?.isMuted = true; image3 = nil; videoURL3 = url
                        case (4, .video(let url)?):
                            video4?.pause(); video4 = nil
                            let pitem4 = AVPlayerItem(url: url); pitem4.preferredForwardBufferDuration = 2
                            video4 = AVPlayer(playerItem: pitem4); video4?.isMuted = true; image4 = nil; videoURL4 = url
                        case (5, .video(let url)?):
                            video5?.pause(); video5 = nil
                            let pitem5 = AVPlayerItem(url: url); pitem5.preferredForwardBufferDuration = 2
                            video5 = AVPlayer(playerItem: pitem5); video5?.isMuted = true; image5 = nil; videoURL5 = url
                        case (6, .video(let url)?):
                            video6?.pause(); video6 = nil
                            let pitem6 = AVPlayerItem(url: url); pitem6.preferredForwardBufferDuration = 2
                            video6 = AVPlayer(playerItem: pitem6); video6?.isMuted = true; image6 = nil; videoURL6 = url
                        default: break
                        }
                    }
                    if let idx = activePaneIndex {
                        setPane(index: idx, media: picked)
                        paneScales[idx - 1] = 1
                        paneOffsets[idx - 1] = .zero
                    }
                    activePaneIndex = nil
                }
            }
        }
        .task(id: item1) { await loadPhoto(item: item1, into: $image1) }
        .task(id: item2) { await loadPhoto(item: item2, into: $image2) }
        .task(id: item3) { await loadPhoto(item: item3, into: $image3) }
        .task(id: item4) { await loadPhoto(item: item4, into: $image4) }
        .onAppear {
            showTemplatePicker = true
        }
    }

    // MARK: - Split content to help type-checker
    @ViewBuilder
    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 12) {
                canvasSection
                // Open settings button
                Button("Border settings") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { showBorderSettings = true }
                }
                .buttonStyle(GlassButtonStyle())
                .padding(.horizontal)
                .padding(.bottom)
                .opacity(showBorderSettings ? 0 : 1)
            }
            .padding(.bottom, showBorderSettings ? max(0, borderPanelHeight - borderPanelDrag) + 16 : 0)

            if showBorderSettings {
                // Bottom slide-up panel
                VStack(spacing: 0) {
                    // Handle / collapse button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { showBorderSettings = false }
                    }) {
                        Image(systemName: "chevron.compact.down")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                    }

                    HStack {
                        Text("Border settings").font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    Divider()

                    ScrollView {
                        borderControls
                    }
                    .frame(maxHeight: 280)
                    .padding(.bottom, 4)
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: -4)
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .offset(y: max(0, borderPanelDrag))
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            let dy = value.translation.height
                            borderPanelDrag = max(0, dy)
                        }
                        .onEnded { value in
                            let dy = value.translation.height
                            if dy > 120 { // threshold to close
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                    showBorderSettings = false
                                    borderPanelDrag = 0
                                }
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                    borderPanelDrag = 0
                                }
                            }
                        }
                )
                .overlay(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { borderPanelHeight = geo.size.height }
                            .onChange(of: geo.size.height) { _, newValue in borderPanelHeight = newValue }
                    }
                )
            }

            // Export progress pill (non-blocking, floats above content)
            if isExportingVideo {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Exporting…")
                            .font(.subheadline.weight(.medium))
                        ProgressView(value: exportProgress)
                            .progressViewStyle(.linear)
                            .tint(.primary)
                            .frame(minWidth: 120)
                    }
                    Text("\(Int(exportProgress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Button {
                        cancelExport = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .overlay(alignment: .top) {
            if let toast = saveToast {
                HStack(spacing: 8) {
                    Image(systemName: toast.contains("ailed") ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(toast.contains("ailed") ? .red : .green)
                    Text(toast)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 2)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isExportingVideo)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: saveToast)
    }

    @ViewBuilder
    private var canvasSection: some View {
        CollageCanvas(
            template: selectedTemplate,
            border: borderStyle,
            image1: $image1,
            image2: $image2,
            image3: $image3,
            image4: $image4,
            image5: $image5,
            image6: $image6,
            player1: $video1,
            player2: $video2,
            player3: $video3,
            player4: $video4,
            player5: $video5,
            player6: $video6,
            backgroundColor: (borderStyle == .separators ? borderColor : Color(UIColor.systemBackground)),
            onPickForPane: { index in
                activePaneIndex = index
                showingSystemPhotoPicker = true
            },
            scales: $paneScales,
            offsets: $paneOffsets,
            spacingOverride: borderGap,
            cornerRadiusOverride: max(0, borderRadius - borderGap),
            hidePaneFrame: hidePaneFrame
        )
        .background(borderStyle == .separators ? borderColor : Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: max(0, borderRadius - borderGap), style: .continuous))
        .padding(borderGap)
        .background(
            RoundedRectangle(cornerRadius: borderRadius, style: .continuous)
                .fill(borderGap > 0 ? AnyShapeStyle(borderColor) : AnyShapeStyle(Color(UIColor.systemBackground)))
        )
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        let w = max(1, geo.size.width)
                        let h = max(1, geo.size.height)
                        canvasAspect = w / h
                    }
                    .onChange(of: geo.size) { _, newSize in
                        let w = max(1, newSize.width)
                        let h = max(1, newSize.height)
                        canvasAspect = w / h
                    }
            }
        )
        .padding(.horizontal)
        .frame(maxHeight: .infinity)
        .scaleEffect(showBorderSettings ? 0.92 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: showBorderSettings)
    }

    @ViewBuilder
    private var borderControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Color")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                ColorPicker("", selection: $borderColor, supportsOpacity: true)
                    .labelsHidden()
            }
            LiquidSlider(label: "Gap", value: $borderGap, range: 0...32, step: 0.5, resetValue: 4)
            LiquidSlider(label: "Radius", value: $borderRadius, range: 0...64, step: 0.5, resetValue: 16)
            Toggle(isOn: $hidePaneFrame) {
                Text("Hide frame")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .tint(.primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // Dynamic row of pickers based on template
    @ViewBuilder
    private var pickerRow: some View {
        let t = selectedTemplate
        HStack(spacing: 12) {
            PhotosPicker(selection: $item1, matching: .images, photoLibrary: .shared()) {
                Label(t == .twoVertical ? "Фото сверху/слева" : "Фото слева/сверху", systemImage: "photo")
            }
            .buttonStyle(.borderedProminent)

            PhotosPicker(selection: $item2, matching: .images, photoLibrary: .shared()) {
                Label(t == .twoVertical ? "Фото снизу/справа" : "Фото справа/снизу", systemImage: "photo")
            }
            .buttonStyle(.borderedProminent)

            if t == .threeOneTopTwoBottom || t == .threeTwoTopOneBottom || t == .threeOneLeftTwoRight || t == .threeTwoLeftOneRight || t == .fourGrid {
                PhotosPicker(selection: $item3, matching: .images, photoLibrary: .shared()) {
                    Label("Третье фото", systemImage: "photo")
                }
                .buttonStyle(.borderedProminent)
            }

            if t == .fourGrid {
                PhotosPicker(selection: $item4, matching: .images, photoLibrary: .shared()) {
                    Label("Четвертое фото", systemImage: "photo")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Rendering & Saving
    private func renderCollage() {
        // Render just the collage canvas with current template.
        // canvasAspect includes the outer border padding, so exportHeight matches preview.
        let exportWidth: CGFloat = 2048
        let exportHeight: CGFloat = max(1, exportWidth / max(0.1, canvasAspect))
        let innerW = exportWidth - 2 * borderGap
        let innerH = exportHeight - 2 * borderGap
        let view = CollageCanvas(template: selectedTemplate,
                                 border: borderStyle,
                                 image1: .constant(image1), image2: .constant(image2), image3: .constant(image3), image4: .constant(image4), image5: .constant(image5), image6: .constant(image6),
                                 player1: .constant(nil), player2: .constant(nil), player3: .constant(nil), player4: .constant(nil), player5: .constant(nil), player6: .constant(nil),
                                 backgroundColor: (borderStyle == .separators ? borderColor : Color(UIColor.systemBackground)),
                                 onPickForPane: { _ in },
                                 scales: .constant(paneScales),
                                 offsets: .constant(paneOffsets),
                                 spacingOverride: borderGap,
                                 cornerRadiusOverride: max(0, borderRadius - borderGap),
                                 hidePaneFrame: hidePaneFrame)
            .frame(width: innerW, height: innerH, alignment: .center)
            .background(borderStyle == .separators ? borderColor : Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: max(0, borderRadius - borderGap), style: .continuous))
            .padding(borderGap)
            .background(
                RoundedRectangle(cornerRadius: borderRadius, style: .continuous)
                    .fill(borderGap > 0 ? AnyShapeStyle(borderColor) : AnyShapeStyle(Color(UIColor.systemBackground)))
            )
            .frame(width: exportWidth, height: exportHeight)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        if let uiImage = renderer.uiImage {
            renderedImage = uiImage
        }
    }

    private func resetCollageMedia() {
        pauseAllVideos()
        image1 = nil; image2 = nil; image3 = nil; image4 = nil; image5 = nil; image6 = nil
        video1 = nil; video2 = nil; video3 = nil; video4 = nil; video5 = nil; video6 = nil
        videoURL1 = nil; videoURL2 = nil; videoURL3 = nil; videoURL4 = nil; videoURL5 = nil; videoURL6 = nil
        item1 = nil; item2 = nil; item3 = nil; item4 = nil
        renderedImage = nil
        activePaneIndex = nil
        paneScales = [1, 1, 1, 1, 1, 1]
        paneOffsets = Array(repeating: .zero, count: 6)
    }

    // MARK: - Helpers to reduce body complexity
    private func hasAnyVideo() -> Bool {
        return [videoURL1, videoURL2, videoURL3, videoURL4, videoURL5, videoURL6].contains { $0 != nil }
    }

    private func showSaveToast(_ message: String) {
        saveToast = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run { saveToast = nil }
        }
    }

    private func saveTapped() {
        if hasAnyVideo() {
            Task { await exportVideoMP4() }
        } else {
            renderCollage()
            guard let img = renderedImage else {
                showSaveToast("Could not render collage")
                return
            }
            UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
            showSaveToast("Saved to Photos")
        }
    }

    // MARK: - Video export helpers

    /// Returns the CGRect for each pane index given template, canvas size, and spacing.
    private func paneRects(for template: Template, canvasSize: CGSize, spacing: CGFloat, margin: CGFloat = 0) -> [Int: CGRect] {
        let w = canvasSize.width - 2 * margin, h = canvasSize.height - 2 * margin
        var r: [Int: CGRect] = [:]
        switch template {
        case .twoHorizontal:
            let pw = (w - spacing) / 2
            r[1] = CGRect(x: 0, y: 0, width: pw, height: h)
            r[2] = CGRect(x: pw + spacing, y: 0, width: pw, height: h)
        case .twoVertical:
            let ph = (h - spacing) / 2
            r[1] = CGRect(x: 0, y: 0, width: w, height: ph)
            r[2] = CGRect(x: 0, y: ph + spacing, width: w, height: ph)
        case .threeOneTopTwoBottom:
            let ph = (h - spacing) / 2, pw = (w - spacing) / 2
            r[1] = CGRect(x: 0, y: 0, width: w, height: ph)
            r[2] = CGRect(x: 0, y: ph + spacing, width: pw, height: ph)
            r[3] = CGRect(x: pw + spacing, y: ph + spacing, width: pw, height: ph)
        case .threeTwoTopOneBottom:
            let ph = (h - spacing) / 2, pw = (w - spacing) / 2
            r[1] = CGRect(x: 0, y: 0, width: pw, height: ph)
            r[2] = CGRect(x: pw + spacing, y: 0, width: pw, height: ph)
            r[3] = CGRect(x: 0, y: ph + spacing, width: w, height: ph)
        case .threeOneLeftTwoRight:
            let pw = (w - spacing) / 2, ph = (h - spacing) / 2
            r[1] = CGRect(x: 0, y: 0, width: pw, height: h)
            r[2] = CGRect(x: pw + spacing, y: 0, width: pw, height: ph)
            r[3] = CGRect(x: pw + spacing, y: ph + spacing, width: pw, height: ph)
        case .threeTwoLeftOneRight:
            let pw = (w - spacing) / 2, ph = (h - spacing) / 2
            r[1] = CGRect(x: 0, y: 0, width: pw, height: ph)
            r[2] = CGRect(x: 0, y: ph + spacing, width: pw, height: ph)
            r[3] = CGRect(x: pw + spacing, y: 0, width: pw, height: h)
        case .fourGrid:
            let pw = (w - spacing) / 2, ph = (h - spacing) / 2
            r[1] = CGRect(x: 0, y: 0, width: pw, height: ph)
            r[2] = CGRect(x: pw + spacing, y: 0, width: pw, height: ph)
            r[3] = CGRect(x: 0, y: ph + spacing, width: pw, height: ph)
            r[4] = CGRect(x: pw + spacing, y: ph + spacing, width: pw, height: ph)
        case .fiveTopGridBottomBig:
            // pane5 has fixed height = (h - 2*spacing) * 0.5; two rows share remaining equally
            let rowH = (h - 2 * spacing) / 4
            let pane5H = (h - 2 * spacing) * 0.5
            let pw = (w - spacing) / 2
            r[1] = CGRect(x: 0, y: 0, width: pw, height: rowH)
            r[2] = CGRect(x: pw + spacing, y: 0, width: pw, height: rowH)
            r[3] = CGRect(x: 0, y: rowH + spacing, width: pw, height: rowH)
            r[4] = CGRect(x: pw + spacing, y: rowH + spacing, width: pw, height: rowH)
            r[5] = CGRect(x: 0, y: 2 * rowH + 2 * spacing, width: w, height: pane5H)
        case .sixGrid:
            let pw = (w - 2 * spacing) / 3, ph = (h - spacing) / 2
            r[1] = CGRect(x: 0, y: 0, width: pw, height: ph)
            r[2] = CGRect(x: pw + spacing, y: 0, width: pw, height: ph)
            r[3] = CGRect(x: 2 * (pw + spacing), y: 0, width: pw, height: ph)
            r[4] = CGRect(x: 0, y: ph + spacing, width: pw, height: ph)
            r[5] = CGRect(x: pw + spacing, y: ph + spacing, width: pw, height: ph)
            r[6] = CGRect(x: 2 * (pw + spacing), y: ph + spacing, width: pw, height: ph)
        case .sixTwoPerRow:
            let pw = (w - spacing) / 2, ph = (h - 2 * spacing) / 3
            r[1] = CGRect(x: 0, y: 0, width: pw, height: ph)
            r[2] = CGRect(x: pw + spacing, y: 0, width: pw, height: ph)
            r[3] = CGRect(x: 0, y: ph + spacing, width: pw, height: ph)
            r[4] = CGRect(x: pw + spacing, y: ph + spacing, width: pw, height: ph)
            r[5] = CGRect(x: 0, y: 2 * (ph + spacing), width: pw, height: ph)
            r[6] = CGRect(x: pw + spacing, y: 2 * (ph + spacing), width: pw, height: ph)
        }
        if margin != 0 {
            return r.mapValues { CGRect(x: $0.minX + margin, y: $0.minY + margin, width: $0.width, height: $0.height) }
        }
        return r
    }

    /// Aspect-fill rect: fits imageSize into destRect with cropping (centered).
    private func aspectFillRect(imageSize: CGSize, in destRect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return destRect }
        let scale = max(destRect.width / imageSize.width, destRect.height / imageSize.height)
        let sw = imageSize.width * scale, sh = imageSize.height * scale
        return CGRect(x: destRect.minX + (destRect.width - sw) / 2,
                      y: destRect.minY + (destRect.height - sh) / 2,
                      width: sw, height: sh)
    }

    /// Draws cgImage aspect-fill into destRect with optional rounded clip in ctx.
    private func drawImageInPane(_ cgImage: CGImage, into destRect: CGRect, cornerRadius: CGFloat, ctx: CGContext,
                                 userScale: CGFloat = 1, userOffset: CGSize = .zero) {
        var fillRect = aspectFillRect(imageSize: CGSize(width: cgImage.width, height: cgImage.height), in: destRect)
        // Apply user scale (around pane center) and offset
        if userScale != 1 || userOffset != .zero {
            let cx = destRect.midX
            let cy = destRect.midY
            let newW = fillRect.width * userScale
            let newH = fillRect.height * userScale
            fillRect = CGRect(x: cx - newW / 2 + userOffset.width,
                              y: cy - newH / 2 + userOffset.height,
                              width: newW, height: newH)
        }
        // Always clip to destRect so aspect-fill doesn't bleed into adjacent panes.
        ctx.saveGState()
        if cornerRadius > 0 {
            ctx.addPath(CGPath(roundedRect: destRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
        } else {
            ctx.addRect(destRect)
        }
        ctx.clip()
        ctx.draw(cgImage, in: fillRect)
        ctx.restoreGState()
    }

    /// Renders all panes (static + video) into one CVPixelBuffer in a single CGContext pass.
    /// The outer border is handled by the background color filling the margin area in paneRects.
    private func renderAllPanes(
        videoFrames: [Int: CGImage],
        staticImages: [Int: CGImage],
        rects: [Int: CGRect],
        canvasSize: CGSize,
        bgCGColor: CGColor,
        pool: CVPixelBufferPool,
        transforms: [Int: (scale: CGFloat, offset: CGSize)] = [:]
    ) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb) == kCVReturnSuccess, let pb else { return nil }
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pb),
            width: Int(canvasSize.width), height: Int(canvasSize.height),
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo
        ) else { return nil }
        ctx.interpolationQuality = .high
        // Flip Y so (0,0) = visual top-left (matches UIImage/AVAssetImageGenerator row order).
        ctx.translateBy(x: 0, y: canvasSize.height)
        ctx.scaleBy(x: 1, y: -1)
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        // Background
        ctx.setFillColor(bgCGColor)
        ctx.fill(canvasRect)
        // Static images (cornerRadius=0; clipping is always applied in drawImageInPane)
        for (idx, cg) in staticImages {
            if let rect = rects[idx] {
                let t = transforms[idx]
                drawImageInPane(cg, into: rect, cornerRadius: 0, ctx: ctx,
                                userScale: t?.scale ?? 1, userOffset: t?.offset ?? .zero)
            }
        }
        // Video frames — AVAssetImageGenerator returns CGImages in CGContext native orientation
        // (row 0 = visual bottom), opposite to UIImage.cgImage (row 0 = visual top).
        // Apply a local Y-flip around each pane rect to counteract the global Y-flip.
        for (idx, cg) in videoFrames {
            if let rect = rects[idx] {
                let t = transforms[idx]
                ctx.saveGState()
                ctx.translateBy(x: 0, y: rect.minY + rect.maxY)
                ctx.scaleBy(x: 1, y: -1)
                drawImageInPane(cg, into: rect, cornerRadius: 0, ctx: ctx,
                                userScale: t?.scale ?? 1, userOffset: t?.offset ?? .zero)
                ctx.restoreGState()
            }
        }
        return pb
    }

    // MARK: - Video export (MP4) — direct all-pane rendering, one generator per video
    private func exportVideoMP4(fps: Int32 = 24, maxDuration: Double = 15.0) async {
        let urlPairs: [(URL?, Int)] = [
            (videoURL1, 1), (videoURL2, 2), (videoURL3, 3),
            (videoURL4, 4), (videoURL5, 5), (videoURL6, 6)
        ]
        let videoEntries = urlPairs.compactMap { pair -> (url: URL, paneIndex: Int)? in
            guard let url = pair.0 else { return nil }
            return (url: url, paneIndex: pair.1)
        }
        guard !videoEntries.isEmpty else {
            renderCollage()
            if let img = renderedImage {
                UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                showSaveToast("Saved to Photos")
            } else {
                showSaveToast("Could not render collage")
            }
            return
        }

        // Static CGImages for non-video panes
        var staticCGImages: [Int: CGImage] = [:]
        for (img, idx) in [(image1,1),(image2,2),(image3,3),(image4,4),(image5,5),(image6,6)] as [(UIImage?,Int)] {
            if let cg = img?.cgImage { staticCGImages[idx] = cg }
        }

        // One AVAssetImageGenerator per video pane — no intermediate H.264 re-encoding.
        // This avoids orientation bugs that occur when reading back encoded composites
        // (the re-encoded video may carry rotation metadata from AVAssetWriter that
        // AVAssetImageGenerator then misapplies via appliesPreferredTrackTransform).
        let tol = CMTime(value: 1, timescale: fps)
        var generators: [Int: AVAssetImageGenerator] = [:]
        var videoDurations: [Int: Double] = [:]
        var maxDur: Double = 0
        for entry in videoEntries {
            let asset = AVURLAsset(url: entry.url)
            if let dur = try? await asset.load(.duration) {
                videoDurations[entry.paneIndex] = dur.seconds
                maxDur = max(maxDur, dur.seconds)
            }
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.requestedTimeToleranceBefore = tol
            gen.requestedTimeToleranceAfter = tol
            generators[entry.paneIndex] = gen
        }

        guard maxDur > 0 else {
            renderCollage()
            if let img = renderedImage {
                UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                showSaveToast("Saved to Photos")
            } else {
                showSaveToast("Could not render collage")
            }
            return
        }
        let duration = min(maxDur, maxDuration)
        let totalFrames = Int(Double(fps) * duration)

        // Round height to even to satisfy H.264 block requirements.
        let exportWidth: CGFloat = 1080
        let exportHeightRaw = exportWidth / max(0.01, canvasAspect)
        let exportHeight: CGFloat = CGFloat(Int(exportHeightRaw / 2) * 2)
        let canvasSize = CGSize(width: exportWidth, height: exportHeight)

        let spacing: CGFloat = borderGap
        let bgCGColor = UIColor(borderStyle == .separators ? borderColor : Color(UIColor.systemBackground)).cgColor
        // Outer border is the background color filling the margin area — no separate stroke needed.
        let rects = paneRects(for: selectedTemplate, canvasSize: canvasSize, spacing: spacing, margin: spacing)
        // Capture transforms on MainActor before background processing
        let capturedScales = paneScales
        let capturedOffsets = paneOffsets
        let exportTransforms: [Int: (scale: CGFloat, offset: CGSize)] = Dictionary(
            uniqueKeysWithValues: (1...6).map { i in (i, (capturedScales[i-1], capturedOffsets[i-1])) }
        )

        await MainActor.run { isExportingVideo = true; exportProgress = 0; cancelExport = false }

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("colexport_\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: tmpURL)
        guard let writer = try? AVAssetWriter(outputURL: tmpURL, fileType: .mp4) else {
            await MainActor.run { isExportingVideo = false; showSaveToast("Export failed") }
            return
        }
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(canvasSize.width),
            AVVideoHeightKey: Int(canvasSize.height)
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        let poolAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(canvasSize.width),
            kCVPixelBufferHeightKey as String: Int(canvasSize.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: poolAttrs)
        guard writer.canAdd(writerInput) else {
            await MainActor.run { isExportingVideo = false; showSaveToast("Export failed") }
            return
        }
        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameDuration = CMTime(value: 1, timescale: fps)
        let outputURL: URL? = await withCheckedContinuation { continuation in
            var frameCount: Int64 = 0
            var done = false
            var lastFrames: [Int: CGImage] = [:]  // per-pane fallback when extraction fails
            writerInput.requestMediaDataWhenReady(on: DispatchQueue(label: "colexport.queue")) {
                guard !done else { return }
                while writerInput.isReadyForMoreMediaData && frameCount < Int64(totalFrames) {
                    if self.cancelExport {
                        done = true
                        writerInput.markAsFinished()
                        writer.cancelWriting()
                        continuation.resume(returning: nil)
                        return
                    }
                    var breakLoop = false
                    autoreleasepool {
                        let t = min(CMTimeMultiply(frameDuration, multiplier: Int32(frameCount)).seconds, duration)
                        // Extract one frame per video pane
                        var videoFrames: [Int: CGImage] = [:]
                        for (paneIdx, gen) in generators {
                            let vidDur = videoDurations[paneIdx] ?? duration
                            let vidCM = CMTime(seconds: min(t, vidDur), preferredTimescale: fps)
                            if let cg = try? gen.copyCGImage(at: vidCM, actualTime: nil) {
                                videoFrames[paneIdx] = cg
                                lastFrames[paneIdx] = cg
                            } else if let last = lastFrames[paneIdx] {
                                // Reuse last good frame (handles transient failures after
                                // background/foreground cycles without spinning the loop).
                                videoFrames[paneIdx] = last
                            }
                        }
                        if videoFrames.isEmpty {
                            // No frames yet — yield back to system and retry.
                            breakLoop = true; return
                        }
                        guard let pool = adaptor.pixelBufferPool,
                              let pb = self.renderAllPanes(
                                  videoFrames: videoFrames,
                                  staticImages: staticCGImages,
                                  rects: rects,
                                  canvasSize: canvasSize,
                                  bgCGColor: bgCGColor,
                                  pool: pool,
                                  transforms: exportTransforms
                              ) else { frameCount += 1; return }
                        adaptor.append(pb, withPresentationTime: CMTimeMultiply(frameDuration, multiplier: Int32(frameCount)))
                        frameCount += 1
                        let progress = Double(frameCount) / Double(totalFrames)
                        DispatchQueue.main.async { self.exportProgress = progress }
                    }
                    if breakLoop { break }
                }
                if !done && frameCount >= Int64(totalFrames) {
                    done = true
                    writerInput.markAsFinished()
                    writer.finishWriting { continuation.resume(returning: tmpURL) }
                }
            }
        }

        if cancelExport {
            await MainActor.run { isExportingVideo = false; exportProgress = 0 }
            return
        }
        if let finalURL = outputURL {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: finalURL)
                }
                await MainActor.run { isExportingVideo = false; showSaveToast("Video saved to Photos") }
            } catch {
                await MainActor.run { isExportingVideo = false; showSaveToast("Save failed") }
            }
        } else {
            await MainActor.run { isExportingVideo = false; showSaveToast("Export failed") }
        }
    }

    // MARK: - Loaders
    private func loadPhoto(item: PhotosPickerItem?, into binding: Binding<UIImage?>) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
            binding.wrappedValue = uiImage
        }
    }
}

// MARK: - Style Picker Sheet (top-level)
struct StylePickerView: View {
    @Binding var selection: ContentView.BorderStyle
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text("Style")
                .font(.headline)
                .padding()
            List {
                ForEach(Array(ContentView.BorderStyle.allCases), id: \.self) { style in
                    Button {
                        selection = style
                        isPresented = false
                    } label: {
                        HStack(spacing: 12) {
                            stylePreview(style)
                            Text(style.rawValue)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selection == style { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button("Close") { isPresented = false }
                .padding()
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func stylePreview(_ style: ContentView.BorderStyle) -> some View {
        let r: CGFloat = 6
        ZStack {
            Color.black
            HStack(spacing: 4) {
                Rectangle().fill(Color.white)
                Rectangle().fill(Color.white)
            }
            .padding(3)
        }
        .frame(width: 56, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: r))
        .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Template Picker Sheet
struct TemplatePickerView: View {
    @Binding var selected: ContentView.Template
    @Binding var isPresented: Bool

    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 130), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text("Template")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ContentView.Template.allCases) { t in
                        let isSelected = selected == t
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selected = t
                            isPresented = false
                        } label: {
                            VStack(spacing: 8) {
                                TemplatePreview(template: t)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(isSelected
                                          ? AnyShapeStyle(.thinMaterial)
                                          : AnyShapeStyle(Color.primary.opacity(0.06)))
                                    .overlay {
                                        if isSelected {
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1.5)
                                        }
                                    }
                            }
                            .shadow(color: isSelected ? .black.opacity(0.08) : .clear,
                                    radius: 8, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.regularMaterial)
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
    }
}

// MARK: - Collage Canvas (arranges panes)
struct CollageCanvas: View {
    let template: ContentView.Template
    let border: ContentView.BorderStyle
    @Binding var image1: UIImage?
    @Binding var image2: UIImage?
    @Binding var image3: UIImage?
    @Binding var image4: UIImage?
    @Binding var image5: UIImage?
    @Binding var image6: UIImage?
    @Binding var player1: AVPlayer?
    @Binding var player2: AVPlayer?
    @Binding var player3: AVPlayer?
    @Binding var player4: AVPlayer?
    @Binding var player5: AVPlayer?
    @Binding var player6: AVPlayer?
    var backgroundColor: Color
    var onPickForPane: (Int) -> Void
    @Binding var scales: [CGFloat]
    @Binding var offsets: [CGSize]
    var spacingOverride: CGFloat? = nil
    var cornerRadiusOverride: CGFloat? = nil
    var hidePaneFrame: Bool = false

    var body: some View {
        GeometryReader { geo in
            let spacing = spacingOverride ?? border.defaultSpacing
            let radius = cornerRadiusOverride ?? 0
            let size = geo.size
            content(size: size, spacing: spacing, radius: radius)
                .frame(width: size.width, height: size.height)
        }
    }

    @ViewBuilder
    private func content(size: CGSize, spacing: CGFloat, radius: CGFloat) -> some View {
        switch template {
        case .twoHorizontal:
            HStack(spacing: spacing) {
                CollagePane(image: $image1, player: player1, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                            scale: $scales[0], offset: $offsets[0],
                            onTapEmpty: { onPickForPane(1) },
                            onLongPressReplace: { onPickForPane(1) })
                CollagePane(image: $image2, player: player2, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                            scale: $scales[1], offset: $offsets[1],
                            onTapEmpty: { onPickForPane(2) },
                            onLongPressReplace: { onPickForPane(2) })
            }
        case .twoVertical:
            VStack(spacing: spacing) {
                CollagePane(image: $image1, player: player1, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                            scale: $scales[0], offset: $offsets[0],
                            onTapEmpty: { onPickForPane(1) },
                            onLongPressReplace: { onPickForPane(1) })
                CollagePane(image: $image2, player: player2, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                            scale: $scales[1], offset: $offsets[1],
                            onTapEmpty: { onPickForPane(2) },
                            onLongPressReplace: { onPickForPane(2) })
            }
        case .threeOneTopTwoBottom:
            VStack(spacing: spacing) {
                CollagePane(image: $image1, player: player1, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                            scale: $scales[0], offset: $offsets[0],
                            onTapEmpty: { onPickForPane(1) },
                            onLongPressReplace: { onPickForPane(1) })
                    .frame(height: (size.height - spacing) * 0.5)
                HStack(spacing: spacing) {
                    CollagePane(image: $image2, player: player2, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                                scale: $scales[1], offset: $offsets[1],
                                onTapEmpty: { onPickForPane(2) },
                                onLongPressReplace: { onPickForPane(2) })
                    CollagePane(image: $image3, player: player3, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                                scale: $scales[2], offset: $offsets[2],
                                onTapEmpty: { onPickForPane(3) },
                                onLongPressReplace: { onPickForPane(3) })
                }
            }
        case .threeTwoTopOneBottom:
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    CollagePane(image: $image1, player: player1, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                                scale: $scales[0], offset: $offsets[0],
                                onTapEmpty: { onPickForPane(1) },
                                onLongPressReplace: { onPickForPane(1) })
                    CollagePane(image: $image2, player: player2, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                                scale: $scales[1], offset: $offsets[1],
                                onTapEmpty: { onPickForPane(2) },
                                onLongPressReplace: { onPickForPane(2) })
                }
                CollagePane(image: $image3, player: player3, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                            scale: $scales[2], offset: $offsets[2],
                            onTapEmpty: { onPickForPane(3) },
                            onLongPressReplace: { onPickForPane(3) })
                    .frame(height: (size.height - spacing) * 0.5)
            }
        case .threeOneLeftTwoRight:
            HStack(spacing: spacing) {
                CollagePane(image: $image1, player: player1, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                            scale: $scales[0], offset: $offsets[0],
                            onTapEmpty: { onPickForPane(1) },
                            onLongPressReplace: { onPickForPane(1) })
                    .frame(width: (size.width - spacing) * 0.5)
                VStack(spacing: spacing) {
                    CollagePane(image: $image2, player: player2, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                                scale: $scales[1], offset: $offsets[1],
                                onTapEmpty: { onPickForPane(2) },
                                onLongPressReplace: { onPickForPane(2) })
                    CollagePane(image: $image3, player: player3, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                                scale: $scales[2], offset: $offsets[2],
                                onTapEmpty: { onPickForPane(3) },
                                onLongPressReplace: { onPickForPane(3) })
                }
            }
        case .threeTwoLeftOneRight:
            HStack(spacing: spacing) {
                VStack(spacing: spacing) {
                    CollagePane(image: $image1, player: player1, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                                scale: $scales[0], offset: $offsets[0],
                                onTapEmpty: { onPickForPane(1) },
                                onLongPressReplace: { onPickForPane(1) })
                    CollagePane(image: $image2, player: player2, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                                scale: $scales[1], offset: $offsets[1],
                                onTapEmpty: { onPickForPane(2) },
                                onLongPressReplace: { onPickForPane(2) })
                }
                .frame(width: (size.width - spacing) * 0.5)
                CollagePane(image: $image3, player: player3, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                            scale: $scales[2], offset: $offsets[2],
                            onTapEmpty: { onPickForPane(3) },
                            onLongPressReplace: { onPickForPane(3) })
            }
        case .fourGrid:
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    CollagePane(image: $image1, player: player1, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                                scale: $scales[0], offset: $offsets[0],
                                onTapEmpty: { onPickForPane(1) },
                                onLongPressReplace: { onPickForPane(1) })
                    CollagePane(image: $image2, player: player2, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                                scale: $scales[1], offset: $offsets[1],
                                onTapEmpty: { onPickForPane(2) },
                                onLongPressReplace: { onPickForPane(2) })
                }
                HStack(spacing: spacing) {
                    CollagePane(image: $image3, player: player3, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                                scale: $scales[2], offset: $offsets[2],
                                onTapEmpty: { onPickForPane(3) },
                                onLongPressReplace: { onPickForPane(3) })
                    CollagePane(image: $image4, player: player4, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                                scale: $scales[3], offset: $offsets[3],
                                onTapEmpty: { onPickForPane(4) },
                                onLongPressReplace: { onPickForPane(4) })
                }
            }
        case .fiveTopGridBottomBig:
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    CollagePane(image: $image1, player: player1, radius: radius, border: border,
                                scale: $scales[0], offset: $offsets[0],
                                onTapEmpty: { onPickForPane(1) },
                                onLongPressReplace: { onPickForPane(1) })
                    CollagePane(image: $image2, player: player2, radius: radius, border: border,
                                scale: $scales[1], offset: $offsets[1],
                                onTapEmpty: { onPickForPane(2) },
                                onLongPressReplace: { onPickForPane(2) })
                }
                HStack(spacing: spacing) {
                    CollagePane(image: $image3, player: player3, radius: radius, border: border,
                                scale: $scales[2], offset: $offsets[2],
                                onTapEmpty: { onPickForPane(3) },
                                onLongPressReplace: { onPickForPane(3) })
                    CollagePane(image: $image4, player: player4, radius: radius, border: border,
                                scale: $scales[3], offset: $offsets[3],
                                onTapEmpty: { onPickForPane(4) },
                                onLongPressReplace: { onPickForPane(4) })
                }
                CollagePane(image: $image5, player: player5, radius: radius, border: border,
                            scale: $scales[4], offset: $offsets[4],
                            onTapEmpty: { onPickForPane(5) },
                            onLongPressReplace: { onPickForPane(5) })
                    .frame(height: (size.height - spacing*2) * 0.5)
            }
        case .sixGrid:
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    CollagePane(image: $image1, player: player1, radius: radius, border: border,
                                scale: $scales[0], offset: $offsets[0],
                                onTapEmpty: { onPickForPane(1) },
                                onLongPressReplace: { onPickForPane(1) })
                    CollagePane(image: $image2, player: player2, radius: radius, border: border,
                                scale: $scales[1], offset: $offsets[1],
                                onTapEmpty: { onPickForPane(2) },
                                onLongPressReplace: { onPickForPane(2) })
                    CollagePane(image: $image3, player: player3, radius: radius, border: border,
                                scale: $scales[2], offset: $offsets[2],
                                onTapEmpty: { onPickForPane(3) },
                                onLongPressReplace: { onPickForPane(3) })
                }
                HStack(spacing: spacing) {
                    CollagePane(image: $image4, player: player4, radius: radius, border: border,
                                scale: $scales[3], offset: $offsets[3],
                                onTapEmpty: { onPickForPane(4) },
                                onLongPressReplace: { onPickForPane(4) })
                    CollagePane(image: $image5, player: player5, radius: radius, border: border,
                                scale: $scales[4], offset: $offsets[4],
                                onTapEmpty: { onPickForPane(5) },
                                onLongPressReplace: { onPickForPane(5) })
                    CollagePane(image: $image6, player: player6, radius: radius, border: border,
                                scale: $scales[5], offset: $offsets[5],
                                onTapEmpty: { onPickForPane(6) },
                                onLongPressReplace: { onPickForPane(6) })
                }
            }
        case .sixTwoPerRow:
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    CollagePane(image: $image1, player: player1, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                                scale: $scales[0], offset: $offsets[0],
                                onTapEmpty: { onPickForPane(1) },
                                onLongPressReplace: { onPickForPane(1) })
                    CollagePane(image: $image2, player: player2, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                                scale: $scales[1], offset: $offsets[1],
                                onTapEmpty: { onPickForPane(2) },
                                onLongPressReplace: { onPickForPane(2) })
                }
                HStack(spacing: spacing) {
                    CollagePane(image: $image3, player: player3, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                                scale: $scales[2], offset: $offsets[2],
                                onTapEmpty: { onPickForPane(3) },
                                onLongPressReplace: { onPickForPane(3) })
                    CollagePane(image: $image4, player: player4, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                                scale: $scales[3], offset: $offsets[3],
                                onTapEmpty: { onPickForPane(4) },
                                onLongPressReplace: { onPickForPane(4) })
                }
                HStack(spacing: spacing) {
                    CollagePane(image: $image5, player: player5, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                                scale: $scales[4], offset: $offsets[4],
                                onTapEmpty: { onPickForPane(5) },
                                onLongPressReplace: { onPickForPane(5) })
                    CollagePane(image: $image6, player: player6, radius: radius, border: border, backgroundColor: backgroundColor, hidePaneFrame: hidePaneFrame,
                                scale: $scales[5], offset: $offsets[5],
                                onTapEmpty: { onPickForPane(6) },
                                onLongPressReplace: { onPickForPane(6) })
                }
            }
        }
    }
}

// MARK: - Visual preview for templates
struct TemplatePreview: View {
    let template: ContentView.Template
    var body: some View {
        ZStack {
            Color.secondary.opacity(0.1)
            layout
                .padding(2)
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var layout: some View {
        let stroke = RoundedRectangle(cornerRadius: 6).stroke(Color.secondary, lineWidth: 1)
        switch template {
        case .twoHorizontal:
            HStack(spacing: 2) {
                Rectangle().fill(Color.clear).overlay(stroke)
                Rectangle().fill(Color.clear).overlay(stroke)
            }
        case .twoVertical:
            VStack(spacing: 2) {
                Rectangle().fill(Color.clear).overlay(stroke)
                Rectangle().fill(Color.clear).overlay(stroke)
            }
        case .threeOneTopTwoBottom:
            VStack(spacing: 2) {
                Rectangle().fill(Color.clear).overlay(stroke)
                HStack(spacing: 2) {
                    Rectangle().fill(Color.clear).overlay(stroke)
                    Rectangle().fill(Color.clear).overlay(stroke)
                }
            }
        case .threeTwoTopOneBottom:
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Rectangle().fill(Color.clear).overlay(stroke)
                    Rectangle().fill(Color.clear).overlay(stroke)
                }
                Rectangle().fill(Color.clear).overlay(stroke)
            }
        case .threeOneLeftTwoRight:
            HStack(spacing: 2) {
                Rectangle().fill(Color.clear).overlay(stroke)
                VStack(spacing: 2) {
                    Rectangle().fill(Color.clear).overlay(stroke)
                    Rectangle().fill(Color.clear).overlay(stroke)
                }
            }
        case .threeTwoLeftOneRight:
            HStack(spacing: 2) {
                VStack(spacing: 2) {
                    Rectangle().fill(Color.clear).overlay(stroke)
                    Rectangle().fill(Color.clear).overlay(stroke)
                }
                Rectangle().fill(Color.clear).overlay(stroke)
            }
        case .fourGrid:
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Rectangle().fill(Color.clear).overlay(stroke)
                    Rectangle().fill(Color.clear).overlay(stroke)
                }
                HStack(spacing: 2) {
                    Rectangle().fill(Color.clear).overlay(stroke)
                    Rectangle().fill(Color.clear).overlay(stroke)
                }
            }
        case .fiveTopGridBottomBig:
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Rectangle().fill(Color.clear).overlay(stroke)
                    Rectangle().fill(Color.clear).overlay(stroke)
                }
                HStack(spacing: 2) {
                    Rectangle().fill(Color.clear).overlay(stroke)
                    Rectangle().fill(Color.clear).overlay(stroke)
                }
                Rectangle().fill(Color.clear).overlay(stroke)
            }
        case .sixGrid:
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Rectangle().fill(Color.clear).overlay(stroke)
                    Rectangle().fill(Color.clear).overlay(stroke)
                    Rectangle().fill(Color.clear).overlay(stroke)
                }
                HStack(spacing: 2) {
                    Rectangle().fill(Color.clear).overlay(stroke)
                    Rectangle().fill(Color.clear).overlay(stroke)
                    Rectangle().fill(Color.clear).overlay(stroke)
                }
            }
        case .sixTwoPerRow:
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Rectangle().fill(Color.clear).overlay(stroke)
                    Rectangle().fill(Color.clear).overlay(stroke)
                }
                HStack(spacing: 2) {
                    Rectangle().fill(Color.clear).overlay(stroke)
                    Rectangle().fill(Color.clear).overlay(stroke)
                }
                HStack(spacing: 2) {
                    Rectangle().fill(Color.clear).overlay(stroke)
                    Rectangle().fill(Color.clear).overlay(stroke)
                }
            }
        }
    }
}

// MARK: - Video fill view (aspect-fill, matches export behaviour)
struct VideoFillView: UIViewRepresentable {
    let player: AVPlayer

    /// UIView whose backing layer is AVPlayerLayer so it auto-resizes with bounds.
    class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        init(player: AVPlayer) {
            super.init(frame: .zero)
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspectFill
        }
        required init?(coder: NSCoder) { fatalError() }
    }

    func makeUIView(context: Context) -> PlayerView { PlayerView(player: player) }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

// MARK: - Collage pane with pinch-to-zoom and pan
struct CollagePane: View {
    @Binding var image: UIImage?
    var player: AVPlayer? = nil
    var radius: CGFloat
    var border: ContentView.BorderStyle
    var backgroundColor: Color = Color(UIColor.systemBackground)
    var hidePaneFrame: Bool = false
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    var onTapEmpty: (() -> Void)? = nil
    var onLongPressReplace: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    @State private var lastScale: CGFloat = 1
    @State private var lastOffset: CGSize = .zero
    @State private var endObserver: Any?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                if let player {
                    ZStack {
                        VideoFillView(player: player)
                            .frame(width: size.width, height: size.height)
                            .scaleEffect(scale)
                            .offset(offset)
                            .allowsHitTesting(false) // let the overlay capture gestures
                            .clipped()
                            .onAppear {
                                player.isMuted = true
                                player.play()
                                if let item = player.currentItem {
                                    endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in
                                        player.seek(to: .zero)
                                        player.play()
                                    }
                                }
                            }
                            .onDisappear {
                                if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
                            }

                        // Transparent overlay to handle gestures and transform
                        Color.clear
                            .frame(width: size.width, height: size.height)
                            .contentShape(Rectangle())
                            .animation(.spring(duration: 0.25), value: scale)
                            .gesture(zoomGesture().simultaneously(with: panGesture()))
                            .onTapGesture(count: 2, perform: resetTransform)
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                                    onLongPressReplace?()
                                }
                            )
                    }
                } else if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .clipped()
                        .contentShape(Rectangle())
                        .gesture(zoomGesture().simultaneously(with: panGesture()))
                        .onTapGesture(count: 2, perform: resetTransform)
                        .animation(.spring(duration: 0.25), value: scale)
                        .clipShape(RoundedRectangle(cornerRadius: radius))
                        .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                            onLongPressReplace?()
                        })
                } else {
                    Button(action: { onTapEmpty?() }) {
                        ZStack {
                            Color.clear
                                .frame(width: size.width, height: size.height)
                            VStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text("Pick media")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.secondary.opacity(hidePaneFrame ? 0 : 0.5), lineWidth: hidePaneFrame ? 0 : 1.5)
            )
        }
    }

    // MARK: - Gestures
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(0.5, lastScale * value), 5)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private func panGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func resetTransform() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}

// MARK: - Preview sheet
struct PreviewSheet: View {
    let image: UIImage?
    let onSave: () -> Void
    let onShare: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding()
                } else {
                    Text("No image to preview")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button(action: onSave) { Label("Save", systemImage: "square.and.arrow.down") }
                        .buttonStyle(.borderedProminent)
                    Button(action: onShare) { Label("Save", systemImage: "square.and.arrow.up") }
                        .buttonStyle(.bordered)
                }
                .padding(.bottom)
            }
            .navigationTitle("Preview")
        }
    }
}

// MARK: - UIKit Share Sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - UIKit PHPicker wrapper for in-pane picking
struct SystemPhotoPicker: UIViewControllerRepresentable {
    typealias UIViewControllerType = PHPickerViewController
    var onPicked: (PickedMedia?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .any(of: [.images, .videos])
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: (PickedMedia?) -> Void
        init(onPicked: @escaping (PickedMedia?) -> Void) { self.onPicked = onPicked }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let first = results.first else { self.onPicked(nil); return }
            let provider = first.itemProvider
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    DispatchQueue.main.async {
                        if let img = object as? UIImage { self.onPicked(.image(img)) } else { self.onPicked(nil) }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                    guard let srcURL = url else { DispatchQueue.main.async { self.onPicked(nil) }; return }
                    // Copy to a persistent temp URL
                    let dst = FileManager.default.temporaryDirectory.appendingPathComponent("picked_\(UUID().uuidString).mov")
                    do {
                        if FileManager.default.fileExists(atPath: dst.path) { try? FileManager.default.removeItem(at: dst) }
                        try FileManager.default.copyItem(at: srcURL, to: dst)
                        DispatchQueue.main.async { self.onPicked(.video(dst)) }
                    } catch {
                        DispatchQueue.main.async { self.onPicked(nil) }
                    }
                }
            } else {
                self.onPicked(nil)
            }
        }
    }
}

#else

// Stub for macOS previews so the file compiles without UIKit/PhotosUI
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Collage designer is available on iOS")
                .font(.headline)
            Text("Select an iOS simulator or connect an iPhone to run.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#endif

#Preview {
    ContentView()
}
