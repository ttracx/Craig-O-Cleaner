import SwiftUI

struct SettingsView: View {
    @StateObject private var launchAtLoginManager = LaunchAtLoginManager()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Settings content
            ScrollView {
                VStack(spacing: 20) {
                    // Launch at Login section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("General")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Toggle(isOn: $launchAtLoginManager.isEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Launch at Login")
                                    .font(.body)
                                Text("Automatically start Craig-O-Clean when you log in")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onChange(of: launchAtLoginManager.isEnabled) { oldValue, newValue in
                            if oldValue != newValue {
                                launchAtLoginManager.toggleLaunchAtLogin()
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // About section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: "memorychip.fill")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Craig-O-Clean")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                
                                Text("Version 1.0")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("macOS Memory Manager")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Permissions section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Permissions")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Administrator privileges required for memory purge", systemImage: "lock.shield")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Label("Process termination requires system access", systemImage: "terminal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    Spacer()
                }
                .padding()
            }
            
            Divider()
            
            // Footer with Quit button
            footerView
        }
        .frame(width: 400, height: 500)
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "gearshape.fill")
                .font(.title2)
                .foregroundColor(.blue)
            
            Text("Settings")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var footerView: some View {
        VStack(spacing: 8) {
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit Craig-O-Clean")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            
            Text("This will close the application")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

