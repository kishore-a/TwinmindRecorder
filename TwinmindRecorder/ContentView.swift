//
//  ContentView.swift
//  TwinmindRecorder
//
//  Created by Kishore Shankar Abimanyu on 7/2/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var recorder = AudioRecorderManager()
    @Environment(\.modelContext) private var modelContext
    @State private var showingSegmentDurationPicker = false
    
    var body: some View {
        TabView {
            // Recording Tab
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Header Section
                    VStack(spacing: DesignSystem.Spacing.md) {
                        HStack {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Twinmind")
                                    .font(DesignSystem.Typography.largeTitle)
                                    .foregroundStyle(DesignSystem.Colors.primaryGradient)
                                Text("Audio Recorder")
                                    .font(DesignSystem.Typography.title3)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            Spacer()
                            
                            // Recording status indicator
                            if recorder.isRecording {
                                StatusBadge(
                                    text: recorder.isPaused ? "Paused" : "Recording",
                                    color: recorder.isPaused ? DesignSystem.Colors.warning : DesignSystem.Colors.recording,
                                    icon: recorder.isPaused ? "pause.circle.fill" : "record.circle.fill"
                                )
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    // Segment Duration Configuration Card
                    ModernCard(shadow: DesignSystem.Shadows.medium) {
                        VStack(spacing: DesignSystem.Spacing.md) {
                            HStack {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text("Segment Duration")
                                        .font(DesignSystem.Typography.headline)
                                    Text("\(Int(recorder.segmentDuration)) seconds")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                                Spacer()
                                
                                IconButton(
                                    icon: "slider.horizontal.3",
                                    color: DesignSystem.Colors.primary,
                                    size: 20
                                ) {
                                    showingSegmentDurationPicker = true
                                }
                            }
                            
                            // Visual duration indicator
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(0..<3, id: \.self) { index in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(DesignSystem.Colors.primary.opacity(0.3))
                                        .frame(height: 4)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    // Recording Controls Section
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Main recording button
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Button(action: {
                                if recorder.isRecording {
                                    recorder.stopRecording()
                                } else {
                                    recorder.startRecording()
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(recorder.isRecording ? DesignSystem.Colors.recordingGradient : DesignSystem.Colors.primaryGradient)
                                        .frame(width: 120, height: 120)
                                        .shadow(color: (recorder.isRecording ? DesignSystem.Colors.recording : DesignSystem.Colors.primary).opacity(0.3), radius: 20, x: 0, y: 10)
                                    
                                    Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                                        .font(.system(size: 40, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                            .scaleEffect(recorder.isRecording ? 1.1 : 1.0)
                            .animation(Animations.spring, value: recorder.isRecording)
                            
                            // Recording status text
                            Text(recorder.isRecording ? (recorder.isPaused ? "Recording Paused" : "Recording...") : "Tap to Start Recording")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(recorder.isRecording ? (recorder.isPaused ? DesignSystem.Colors.warning : DesignSystem.Colors.recording) : DesignSystem.Colors.textSecondary)
                                .animation(Animations.easeInOut, value: recorder.isRecording)
                        }
                        
                        // Secondary controls
                        if recorder.isRecording {
                            HStack(spacing: DesignSystem.Spacing.xl) {
                                IconButton(
                                    icon: recorder.isPaused ? "play.circle.fill" : "pause.circle.fill",
                                    color: recorder.isPaused ? DesignSystem.Colors.success : DesignSystem.Colors.warning,
                                    size: 32
                                ) {
                                    if recorder.isPaused {
                                        recorder.resumeRecording()
                                    } else {
                                        recorder.pauseRecording()
                                    }
                                }
                                
                                IconButton(
                                    icon: "stop.circle.fill",
                                    color: DesignSystem.Colors.error,
                                    size: 32
                                ) {
                                    recorder.stopRecording()
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    // Live Waveform Section
                    if recorder.isRecording {
                        ModernCard(shadow: DesignSystem.Shadows.small) {
                            VStack(spacing: DesignSystem.Spacing.md) {
                                HStack {
                                    Text("Live Waveform")
                                        .font(DesignSystem.Typography.headline)
                                    Spacer()
                                    Text(timerString(from: recorder.elapsedTime))
                                        .font(DesignSystem.Typography.title3)
                                        .monospacedDigit()
                                        .foregroundColor(DesignSystem.Colors.primary)
                                }
                                
                                WaveformView(
                                    samples: recorder.waveformSamples,
                                    barColor: DesignSystem.Colors.waveformActive,
                                    barWidth: 3,
                                    spacing: 2,
                                    maxHeight: 80
                                )
                                .frame(maxWidth: .infinity)
                                .clipped()
                            }
                            .padding(DesignSystem.Spacing.lg)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Current Session Info
                    if recorder.isRecording {
                        ModernCard(shadow: DesignSystem.Shadows.small) {
                            VStack(spacing: DesignSystem.Spacing.md) {
                                HStack {
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                        Text("Current Session")
                                            .font(DesignSystem.Typography.headline)
                                        Text("\(recorder.segments.count) segments recorded")
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                    }
                                    Spacer()
                                    
                                    ProgressRing(
                                        progress: min(Double(recorder.segments.count) / 10.0, 1.0),
                                        color: DesignSystem.Colors.primary,
                                        size: 50,
                                        lineWidth: 4
                                    )
                                }
                                
                                // Segment indicators
                                if !recorder.segments.isEmpty {
                                    HStack(spacing: DesignSystem.Spacing.xs) {
                                        ForEach(0..<min(recorder.segments.count, 10), id: \.self) { index in
                                            Circle()
                                                .fill(DesignSystem.Colors.primary)
                                                .frame(width: 8, height: 8)
                                                .scaleEffect(recorder.segments.count == index + 1 ? 1.2 : 1.0)
                                                .animation(Animations.spring, value: recorder.segments.count)
                                        }
                                    }
                                }
                            }
                            .padding(DesignSystem.Spacing.lg)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Error and Permission Messages
                    if let error = recorder.error {
                        ModernCard(shadow: DesignSystem.Shadows.small) {
                            HStack(spacing: DesignSystem.Spacing.md) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(DesignSystem.Colors.error)
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text("Recording Error")
                                        .font(DesignSystem.Typography.subheadline)
                                        .fontWeight(.medium)
                                    Text(error.localizedDescription)
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(DesignSystem.Spacing.lg)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                    
                    if recorder.permissionDenied {
                        ModernCard(shadow: DesignSystem.Shadows.small) {
                            HStack(spacing: DesignSystem.Spacing.md) {
                                Image(systemName: "mic.slash.fill")
                                    .foregroundColor(DesignSystem.Colors.warning)
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text("Microphone Access Required")
                                        .font(DesignSystem.Typography.subheadline)
                                        .fontWeight(.medium)
                                    Text("Please enable microphone access in Settings to record audio")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(DesignSystem.Spacing.lg)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                    
                    Spacer(minLength: DesignSystem.Spacing.xxl)
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.background,
                        DesignSystem.Colors.secondaryBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .tabItem {
                Image(systemName: "mic")
                Text("Record")
            }
            .onAppear {
                recorder.setModelContext(modelContext)
            }
            
            // Sessions Tab
            SessionListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Sessions")
                }
        }
        .sheet(isPresented: $showingSegmentDurationPicker) {
            SegmentDurationPicker(recorder: recorder)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: RecordingSession.self, inMemory: true)
}

// Helper for formatting timer
private func timerString(from time: TimeInterval) -> String {
    let totalSeconds = Int(time)
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d", minutes, seconds)
}
