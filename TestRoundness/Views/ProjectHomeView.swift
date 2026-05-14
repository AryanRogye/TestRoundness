import SwiftUI

struct ProjectHomeView: View {
    let projects: [ProjectSummary]
    let selectedProjectID: UUID?
    let onOpenProject: (UUID) -> Void
    let onNewProject: () -> Void
    let onPasteProject: () -> Void
    let onDeleteProject: (ProjectSummary) -> Void

    @State private var searchText = ""

    private var filteredProjects: [ProjectSummary] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return projects
        }

        return projects.filter { project in
            project.name.localizedCaseInsensitiveContains(searchText)
                || project.sourceName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Projects")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    onPasteProject()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }

                Button {
                    onNewProject()
                } label: {
                    Label("New", systemImage: "photo.badge.plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    quickActions

                    TextField("Search", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Projects")
                            .font(.headline)

                        if filteredProjects.isEmpty {
                            ContentUnavailableView(
                                "No Projects",
                                systemImage: "rectangle.stack.badge.plus",
                                description: Text("Import or paste an image to create the first project.")
                            )
                            .frame(maxWidth: .infinity, minHeight: 260)
                        } else {
                            projectList
                        }
                    }
                }
                .frame(maxWidth: 980, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
            }
        }
        .background(Color(nsColorOrUIColor: .windowBackgroundColor))
    }

    private var quickActions: some View {
        HStack(spacing: 14) {
            ProjectActionButton(
                title: "Design",
                systemImage: "rectangle.dashed",
                color: .blue,
                action: onNewProject
            )

            ProjectActionButton(
                title: "Paste",
                systemImage: "doc.on.clipboard",
                color: .purple,
                action: onPasteProject
            )
        }
    }

    private var projectList: some View {
        LazyVStack(spacing: 10) {
            ForEach(filteredProjects) { project in
                ProjectHomeRow(
                    project: project,
                    isSelected: project.id == selectedProjectID,
                    onOpen: { onOpenProject(project.id) },
                    onDelete: { onDeleteProject(project) }
                )
            }
        }
    }
}

private struct ProjectActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(color, in: Circle())

                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)
            }
            .frame(width: 132, height: 112)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator.opacity(0.65))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ProjectHomeRow: View {
    let project: ProjectSummary
    let isSelected: Bool
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(project.sourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(project.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 150, alignment: .leading)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete project")
        }
        .padding(10)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .onTapGesture(perform: onOpen)
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.4))

            if let thumbnailImage = project.thumbnailImage {
                platformImage(thumbnailImage)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 88, height: 54)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(.separator.opacity(0.65))
        }
        .clipped()
    }

    private func platformImage(_ image: PlatformImage) -> Image {
        #if os(macOS)
        Image(nsImage: image)
        #else
        Image(uiImage: image)
        #endif
    }
}
