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
                        
                        Toggle(isOn: Binding(
                            get: { launchAtLoginManager.isEnabled },
                            set: { newValue in
                                launchAtLoginManager.isEnabled = newValue
                                launchAtLoginManager.toggleLaunchAtLogin()
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Launch at Login")
                                    .font(.body)
                                Text("Automatically start Craig-O-Clean when you log in")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                    
                    // Features section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Real-time memory monitoring", systemImage: "chart.bar.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Label("One-click memory optimization", systemImage: "bolt.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Label("Process management and termination", systemImage: "terminal.fill")
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
            
            // Footer with Quit button and copyright
            footerView
        }
        .frame(width: 440, height: 580)
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
        VStack(spacing: 12) {
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
            
            Divider()
                .padding(.vertical, 4)
            
            // Copyright notice
            VStack(spacing: 4) {
                Text("© 2025 Craig-O-Cleaner")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("powered by VibeCaaS.com")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("a division of NeuralQuantum.ai LLC")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("All rights reserved.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.bottom, 4)
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

