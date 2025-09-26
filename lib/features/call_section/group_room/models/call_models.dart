// models/call_models.dart
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum CallStatus {
  initializing,
  requestingPermissions,
  settingUpVideo,
  connecting,
  connected,
  reconnecting,
  failed,
  ended
}

enum ParticipantStatus {
  joining,
  connected,
  disconnected,
  left
}

class CallState {
  final CallStatus status;
  final String statusMessage;
  final Duration callDuration;
  final bool isMuted;
  final bool isVideoOff;
  final bool isRearCamera;
  final int participantCount;
  final String? error;

  const CallState({
    this.status = CallStatus.initializing,
    this.statusMessage = 'Initializing...',
    this.callDuration = Duration.zero,
    this.isMuted = false,
    this.isVideoOff = false,
    this.isRearCamera = false,
    this.participantCount = 0,
    this.error,
  });

  CallState copyWith({
    CallStatus? status,
    String? statusMessage,
    Duration? callDuration,
    bool? isMuted,
    bool? isVideoOff,
    bool? isRearCamera,
    int? participantCount,
    String? error,
  }) {
    return CallState(
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      callDuration: callDuration ?? this.callDuration,
      isMuted: isMuted ?? this.isMuted,
      isVideoOff: isVideoOff ?? this.isVideoOff,
      isRearCamera: isRearCamera ?? this.isRearCamera,
      participantCount: participantCount ?? this.participantCount,
      error: error ?? this.error,
    );
  }
}

class Participant {
  final String userId;
  final ParticipantStatus status;
  final DateTime joinedAt;
  final RTCVideoRenderer? renderer;
  final RTCPeerConnection? peerConnection;

  const Participant({
    required this.userId,
    required this.status,
    required this.joinedAt,
    this.renderer,
    this.peerConnection,
  });

  Participant copyWith({
    String? userId,
    ParticipantStatus? status,
    DateTime? joinedAt,
    RTCVideoRenderer? renderer,
    RTCPeerConnection? peerConnection,
  }) {
    return Participant(
      userId: userId ?? this.userId,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      renderer: renderer ?? this.renderer,
      peerConnection: peerConnection ?? this.peerConnection,
    );
  }
}

class SignalData {
  final String from;
  final String to;
  final String type;
  final String? sdp;
  final String? candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;
  final DateTime timestamp;

  const SignalData({
    required this.from,
    required this.to,
    required this.type,
    this.sdp,
    this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
    required this.timestamp,
  });

  factory SignalData.fromMap(Map<String, dynamic> map) {
    return SignalData(
      from: map['from'] as String,
      to: map['to'] as String,
      type: map['type'] as String,
      sdp: map['sdp'] as String?,
      candidate: map['candidate'] as String?,
      sdpMid: map['sdpMid'] as String?,
      sdpMLineIndex: map['sdpMLineIndex'] as int?,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'from': from,
      'to': to,
      'type': type,
      if (sdp != null) 'sdp': sdp,
      if (candidate != null) 'candidate': candidate,
      if (sdpMid != null) 'sdpMid': sdpMid,
      if (sdpMLineIndex != null) 'sdpMLineIndex': sdpMLineIndex,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}

