import SwiftUI
import OGPlayerCore

/// Dark, grouped demo launcher:
/// branded header, concern groups, list rows (icon tile, title, one-line
/// description, optional tag chip, chevron), unlicensed footer.
struct LauncherView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    ForEach(demoGroups) { group in
                        Text(group.header)
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(0.6)
                            .foregroundStyle(Ink.groupHeader)
                            .padding(.top, 14).padding(.bottom, 8)
                        ForEach(group.demos) { demo in
                            NavigationLink { demo.destination() } label: { DemoRow(demo) }
                                .buttonStyle(.plain)
                            Spacer().frame(height: 7)
                        }
                    }
                    Text("Unlicensed build — demos render the OGPlayer watermark.")
                        .font(.system(size: 10))
                        .foregroundStyle(Ink.groupHeader)
                        .padding(.top, 14)
                }
                .padding(.horizontal, 16)
            }
            .background(Ink.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            // The launcher is portrait; force it on launch so the app never
            // opens sideways.
            .onAppear { OrientationLock.apply(.portrait) }
        }
        .tint(Ink.accent)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                BrandMark().frame(width: 24, height: 24)
                (Text("OG").foregroundStyle(Ink.accent).bold() + Text("Player").foregroundStyle(Ink.description))
                    .font(.system(size: 17))
                Spacer()
                Text("v" + OGPlayerSDK.version)
                    .font(.system(size: 10))
                    .foregroundStyle(Ink.description)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Ink.tagBg, in: RoundedRectangle(cornerRadius: 5))
            }
            .padding(.top, 12)
            Text("Integration demos")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Ink.title)
                .padding(.top, 16)
            // Derived from the catalog so it never goes stale.
            Text("\(demoGroups.reduce(0) { $0 + $1.demos.count }) scenarios exercising the SDK end to end.")
                .font(.system(size: 12))
                .foregroundStyle(Ink.description)
                .padding(.top, 6)
        }
    }
}

private struct DemoRow: View {
    let demo: Demo
    init(_ demo: Demo) { self.demo = demo }
    var body: some View {
        // Sized ~25% up from the Android dp values: iOS points on a wider
        // screen render relatively smaller, so matching numbers read cramped.
        HStack(spacing: 14) {
            Image(systemName: demo.systemImage)
                .font(.system(size: 18))
                .foregroundStyle(Ink.accent)
                .frame(width: 34, height: 34)
                .background(Ink.iconTile, in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(demo.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Ink.title)
                    if let tag = demo.tag {
                        Text(tag).font(.system(size: 10, weight: .medium)).foregroundStyle(Ink.description)
                            .padding(.horizontal, 6).padding(.vertical, 2.5)
                            .background(Ink.tagBg, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text(demo.description).font(.system(size: 13)).foregroundStyle(Ink.description)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Ink.chevron)
        }
        .padding(.horizontal, 12).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.rowSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Ink.rowBorder, lineWidth: 1))
    }
}

/// Compact OGPlayer identity mark (chamfered aperture + play triangle).
struct BrandMark: View {
    var body: some View {
        Canvas { ctx, size in
            let u = size.width / 32
            var frame = Path()
            frame.move(to: CGPoint(x: 12*u, y: 3*u))
            frame.addLine(to: CGPoint(x: 29*u, y: 3*u))
            frame.addLine(to: CGPoint(x: 29*u, y: 20*u))
            frame.addLine(to: CGPoint(x: 20*u, y: 29*u))
            frame.addLine(to: CGPoint(x: 3*u, y: 29*u))
            frame.addLine(to: CGPoint(x: 3*u, y: 12*u))
            frame.closeSubpath()
            // Aperture frame white 72% (matches the SDK watermark); only the
            // play triangle is accent yellow.
            ctx.stroke(frame, with: .color(.white.opacity(0.72)),
                       style: StrokeStyle(lineWidth: 2.6*u, lineJoin: .round))
            var play = Path()
            play.move(to: CGPoint(x: 13*u, y: 10*u))
            play.addLine(to: CGPoint(x: 22.5*u, y: 16*u))
            play.addLine(to: CGPoint(x: 13*u, y: 22*u))
            play.closeSubpath()
            ctx.fill(play, with: .color(Ink.accent))
        }
    }
}
