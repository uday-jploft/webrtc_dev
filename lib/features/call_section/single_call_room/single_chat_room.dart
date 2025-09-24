import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webrtc_dev/core/utils.dart';

class SingleChatRoom extends StatefulWidget {
  final String roomId;
  final bool isCaller;
  const SingleChatRoom({super.key, required this.roomId, required this.isCaller});

  @override
  State<SingleChatRoom> createState() => _SingleChatRoomState();
}

class _SingleChatRoomState extends State<SingleChatRoom> with TickerProviderStateMixin {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  MediaStream? _localStream;

  bool remoteJoined = false;
  bool isConnecting = false;
  bool isMuted = false;
  bool isVideoOff = false;
  bool isRearCamera = false;
  bool isCallConnected = false;
  String connectionStatus = 'Initializing...';
  String callDuration = '00:00';

  final List<RTCIceCandidate> _remoteCandidateBuffer = [];
  StreamSubscription<DocumentSnapshot>? _roomSub;
  StreamSubscription<QuerySnapshot>? _offerCandidatesSub;
  StreamSubscription<QuerySnapshot>? _answerCandidatesSub;

  Timer? _debugTimer;
  Timer? _callTimer;
  DateTime? _callStartTime;

  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    print('SingleChatRoom initState - Starting initialization...');

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);

    _requestPermissions();

    _debugTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      print('=== Periodic Check ===');
      print('Peer connection: $_pc');
      print('Remote renderer stream: ${_remoteRenderer.srcObject?.id ?? "still null"}');
      print('Local renderer stream: ${_localRenderer.srcObject?.id ?? "still null"}');
      print('Remote joined: $remoteJoined');
      if (_pc != null) {
        print('ICE state: ${_pc!.iceConnectionState}');
        print('Connection state: ${_pc!.connectionState}');
        print('Signaling state: ${_pc!.signalingState}');
      }
    });
  }

  void _startCallTimer() {
    _callStartTime = DateTime.now();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_callStartTime != null && mounted) {
        final duration = DateTime.now().difference(_callStartTime!);
        setState(() {
          callDuration = _formatDuration(duration);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return hours > 0
        ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}'
        : '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Future<void> _requestPermissions() async {
    print('Requesting permissions...');
    setState(() {
      connectionStatus = 'Requesting permissions...';
    });

    Map<Permission, PermissionStatus> permissions = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    bool allGranted = permissions.values.every((status) => status.isGranted);

    if (allGranted) {
      print('All permissions granted, proceeding with initialization...');
      try {
        await _initRenderers();
        await _startCall();
      } catch (e, stackTrace) {
        print('Error in initialization: $e\nStack trace: $stackTrace');
        setState(() {
          connectionStatus = 'Initialization failed';
          isConnecting = false;
        });
        _showErrorDialog('Failed to initialize video call', e.toString());
      }
    } else {
      print('Permissions denied: $permissions');
      setState(() {
        connectionStatus = 'Permissions required';
        isConnecting = false;
      });
      await _showPermissionDialog();
    }
  }

  Future<void> _showErrorDialog(String title, String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.grey[900],
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(message, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              child: const Text('OK', style: TextStyle(color: Colors.blue)),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPermissionDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.grey[900],
          title: const Text('Permissions Required', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Camera and microphone permissions are required for video calls.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: const Text('Exit', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Grant Permissions', style: TextStyle(color: Colors.blue)),
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
                await _requestPermissions();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _initRenderers() async {
    print('Initializing renderers...');
    setState(() {
      connectionStatus = 'Setting up video...';
    });
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    print('Renderers initialized successfully');
  }

  Future<void> _startCall() async {
    setState(() {
      isConnecting = true;
      connectionStatus = widget.isCaller ? 'Calling...' : 'Joining call...';
    });

    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
        {
          'urls': 'turn:openrelay.metered.ca:80',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
      ],
      'iceCandidatePoolSize': 10,
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      'iceTransportPolicy': 'all',
    };

    try {
      print('Creating peer connection...');
      _pc = await createPeerConnection(config);
      _setupPeerConnectionHandlers();
      await _setupLocalStream();
      await _setupSignaling();
    } catch (e, stackTrace) {
      print('Error starting call: $e\nStack trace: $stackTrace');
      setState(() {
        connectionStatus = 'Connection failed';
        isConnecting = false;
      });
      await _cleanup();
      _showErrorDialog('Connection Failed', 'Unable to establish connection.');
    }
  }

  void _setupPeerConnectionHandlers() {
    _pc!.onIceConnectionState = (state) {
      print('ICE Connection State: $state');
      setState(() {
        switch (state) {
          case RTCIceConnectionState.RTCIceConnectionStateConnected:
          case RTCIceConnectionState.RTCIceConnectionStateCompleted:
            connectionStatus = 'Connected';
            isConnecting = false;
            isCallConnected = true;
            _startCallTimer();
            break;
          case RTCIceConnectionState.RTCIceConnectionStateChecking:
            connectionStatus = 'Connecting...';
            break;
          case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
            connectionStatus = 'Reconnecting...';
            isCallConnected = false;
            break;
          case RTCIceConnectionState.RTCIceConnectionStateFailed:
            connectionStatus = 'Connection failed';
            isConnecting = false;
            isCallConnected = false;
            break;
          default:
            break;
        }
      });
    };

    _pc!.onTrack = (event) {
      print('OnTrack: Stream count: ${event.streams.length}');
      if (event.streams.isNotEmpty) {
        setState(() {
          _remoteRenderer.srcObject = event.streams.first;
          remoteJoined = true;
          connectionStatus = 'Connected';
        });
      }
    };

    _pc!.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      print('New ICE candidate: ${candidate.candidate}');
      final roomRef = FirebaseFirestore.instance.collection('rooms').doc('single').collection(widget.roomId).doc(widget.roomId);
      final collection = widget.isCaller ? 'offerCandidates' : 'answerCandidates';
      roomRef.collection(collection).add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };
  }

  Future<void> _setupLocalStream() async {
    print('Setting up local stream...');
    setState(() {
      connectionStatus = 'Accessing camera...';
    });

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'facingMode': 'user',
        'width': {'min': 320, 'ideal': 640, 'max': 1280},
        'height': {'min': 240, 'ideal': 480, 'max': 720},
        'frameRate': {'min': 15, 'ideal': 24, 'max': 30},
      },
    });

    print('Local stream ID: ${_localStream!.id}');
    setState(() {
      _localRenderer.srcObject = _localStream;
    });

    for (var track in _localStream!.getTracks()) {
      await _pc?.addTrack(track, _localStream!);
    }
  }

  Future<void> _setupSignaling() async {
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc('single').collection(widget.roomId).doc(widget.roomId);

    _roomSub = roomRef.snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data == null) return;

      if (!widget.isCaller && data.containsKey('offer') && (await _pc!.getRemoteDescription()) == null) {
        print('Processing offer...');
        final offer = data['offer'] as Map<String, dynamic>;
        await _pc!.setRemoteDescription(RTCSessionDescription(offer['sdp'], offer['type']));
        await _flushRemoteCandidates();

        final answer = await _pc!.createAnswer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': true,
        });
        await _pc!.setLocalDescription(answer);
        await roomRef.update({'answer': answer.toMap()});
      }

      if (widget.isCaller && data.containsKey('answer') && (await _pc!.getRemoteDescription()) == null) {
        print('Processing answer...');
        final answer = data['answer'] as Map<String, dynamic>;
        await _pc!.setRemoteDescription(RTCSessionDescription(answer['sdp'], answer['type']));
        await _flushRemoteCandidates();
      }
    });

    _offerCandidatesSub = roomRef.collection('offerCandidates').snapshots().listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added && !widget.isCaller) {
          _handleRemoteCandidate(doc.doc.data()!);
        }
      }
    });

    _answerCandidatesSub = roomRef.collection('answerCandidates').snapshots().listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added && widget.isCaller) {
          _handleRemoteCandidate(doc.doc.data()!);
        }
      }
    });

    if (widget.isCaller) {
      final offer = await _pc!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await _pc!.setLocalDescription(offer);
      await roomRef.set({'offer': offer.toMap()}, SetOptions(merge: true));
      print('Offer created and sent');
    }
  }

  void _handleRemoteCandidate(Map<String, dynamic> data) async {
    final candidate = data['candidate'] as String?;
    final sdpMid = data['sdpMid'] as String?;
    final sdpMLineIndex = data['sdpMLineIndex'] is int ? data['sdpMLineIndex'] as int : int.tryParse('${data['sdpMLineIndex']}');

    if (candidate == null || sdpMid == null || sdpMLineIndex == null) return;

    final rtcCandidate = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
    if (await _pc!.getRemoteDescription() == null) {
      _remoteCandidateBuffer.add(rtcCandidate);
    } else {
      await _pc!.addCandidate(rtcCandidate);
    }
  }

  Future<void> _flushRemoteCandidates() async {
    for (var candidate in _remoteCandidateBuffer) {
      await _pc?.addCandidate(candidate);
    }
    _remoteCandidateBuffer.clear();
  }

  Future<void> _toggleMute() async {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
      setState(() {
        isMuted = !audioTrack.enabled;
      });
      _showQuickFeedback(isMuted ? 'Microphone off' : 'Microphone on');
    }
  }

  Future<void> _toggleVideo() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      videoTrack.enabled = !videoTrack.enabled;
      setState(() {
        isVideoOff = !videoTrack.enabled;
      });
      _showQuickFeedback(isVideoOff ? 'Camera off' : 'Camera on');
    }
  }

  Future<void> _switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      try {
        await videoTrack.switchCamera();
        setState(() {
          isRearCamera = !isRearCamera;
        });
        _showQuickFeedback('Switched to ${isRearCamera ? "rear" : "front"} camera');
      } catch (e) {
        print('Error switching camera: $e');
        _showQuickFeedback('Unable to switch camera');
      }
    }
  }

  void _showQuickFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.only(bottom: 120, left: 20, right: 20),
      ),
    );
  }

  Future<void> _hangUp() async {
    await _cleanup();
    Navigator.of(context).pop();
  }

  Future<void> _cleanup() async {
    print('Cleaning up resources...');
    try {
      _roomSub?.cancel();
      _offerCandidatesSub?.cancel();
      _answerCandidatesSub?.cancel();
      _debugTimer?.cancel();
      _callTimer?.cancel();
      _pulseController.dispose();
      _fadeController.dispose();

      _localStream?.getTracks().forEach((track) => track.stop());
      _remoteRenderer.srcObject?.getTracks().forEach((track) => track.stop());

      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;

      await _localRenderer.dispose();
      await _remoteRenderer.dispose();
      await _pc?.close();

      final roomRef = FirebaseFirestore.instance.collection('rooms').doc('single').collection(widget.roomId).doc(widget.roomId);
      await roomRef.delete();

      setState(() {
        remoteJoined = false;
        isConnecting = false;
        isCallConnected = false;
        connectionStatus = 'Call ended';
      });
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }

  @override
  void dispose() {
    print('Disposing SingleChatRoom...');
    _cleanup();
    super.dispose();
  }

  Widget _buildStatusBar() {
    Color statusColor = isConnecting
        ? Colors.orange
        : isCallConnected && remoteJoined
        ? Colors.green
        : Colors.red;
    IconData statusIcon = isConnecting
        ? Icons.sync
        : isCallConnected && remoteJoined
        ? Icons.check_circle
        : Icons.error_outline;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            AnimatedBuilder(
              animation: isConnecting ? _pulseAnimation : _fadeAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: isConnecting ? _pulseAnimation.value : 1.0,
                  child: Icon(statusIcon, color: statusColor, size: 20),
                );
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    connectionStatus,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isCallConnected && callDuration != '00:00')
                    Text(
                      callDuration,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => copyToClipboard(context, widget.roomId),
              child: Row(
                children: [
                  Text(
                    'Room: ${widget.roomId}',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const Icon(Icons.copy, color: Colors.white54, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalVideoView() {
    return Positioned(
      top: 100,
      right: 16,
      child: Container(
        width: 120,
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: remoteJoined ? Colors.white.withOpacity(0.3) : Colors.blue,
            width: remoteJoined ? 1 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              if (!isVideoOff && _localRenderer.srcObject != null)
                RTCVideoView(
                  _localRenderer,
                  key: ValueKey('local_${_localRenderer.srcObject?.id}'),
                  mirror: !isRearCamera,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  filterQuality: FilterQuality.medium,
                )
              else
                Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: Icon(Icons.videocam_off, color: Colors.white54, size: 32),
                  ),
                ),
              if (isMuted)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.mic_off, color: Colors.white, size: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.9), Colors.transparent],
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: isMuted ? Icons.mic_off : Icons.mic,
              onPressed: _toggleMute,
              backgroundColor: isMuted ? Colors.red : Colors.white.withOpacity(0.2),
              iconColor: isMuted ? Colors.white : Colors.white,
            ),
            _buildControlButton(
              icon: isVideoOff ? Icons.videocam_off : Icons.videocam,
              onPressed: _toggleVideo,
              backgroundColor: isVideoOff ? Colors.red : Colors.white.withOpacity(0.2),
              iconColor: isVideoOff ? Colors.white : Colors.white,
            ),
            _buildControlButton(
              icon: Icons.call_end,
              onPressed: _hangUp,
              backgroundColor: Colors.red,
              iconColor: Colors.white,
              isLarge: true,
            ),
            _buildControlButton(
              icon: Icons.flip_camera_ios,
              onPressed: _switchCamera,
              backgroundColor: Colors.white.withOpacity(0.2),
              iconColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color iconColor,
    bool isLarge = false,
  }) {
    final size = isLarge ? 64.0 : 52.0;
    final iconSize = isLarge ? 28.0 : 24.0;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(size / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: iconSize),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _remoteRenderer.srcObject != null
                ? RTCVideoView(
              _remoteRenderer,
              key: ValueKey('remote_${_remoteRenderer.srcObject?.id}'),
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              filterQuality: FilterQuality.medium,
            )
                : Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: isConnecting ? _pulseAnimation.value : 1.0,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(60),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white54,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isConnecting ? 'Connecting...' : 'Waiting for participant',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isConnecting)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          _buildStatusBar(),
          if (_localRenderer.srcObject != null) _buildLocalVideoView(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildControlButtons(),
          ),
        ],
      ),
    );
  }
}