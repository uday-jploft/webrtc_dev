// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// class GroupChatRoom extends StatefulWidget {
//   final String roomId;
//   final String userId;
//   const GroupChatRoom({super.key, required this.roomId, required this.userId});
//
//   @override
//   State<GroupChatRoom> createState() => _GroupChatRoomState();
// }
//
// class _GroupChatRoomState extends State<GroupChatRoom> with TickerProviderStateMixin {
//   final _localRenderer = RTCVideoRenderer();
//   final Map<String, RTCVideoRenderer> _remoteRenderers = {};
//   final Map<String, RTCPeerConnection> _peerConnections = {};
//   MediaStream? _localStream;
//
//   bool isConnecting = false;
//   bool isMuted = false;
//   bool isVideoOff = false;
//   bool isRearCamera = false;
//   String connectionStatus = 'Initializing...';
//   String callDuration = '00:00';
//
//   final Map<String, List<RTCIceCandidate>> _remoteCandidateBuffers = {};
//   StreamSubscription<DocumentSnapshot>? _roomSub;
//   StreamSubscription<QuerySnapshot>? _participantsSub;
//   Timer? _debugTimer;
//   Timer? _callTimer;
//   DateTime? _callStartTime;
//
//   late AnimationController _pulseController;
//   late Animation<double> _pulseAnimation;
//
//   @override
//   void initState() {
//     super.initState();
//     print('GroupChatRoom initState - Starting initialization for user ${widget.userId}');
//
//     _pulseController = AnimationController(
//       duration: const Duration(milliseconds: 1500),
//       vsync: this,
//     );
//     _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
//       CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
//     );
//     _pulseController.repeat(reverse: true);
//
//     _requestPermissions();
//
//     _debugTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
//       print('=== Periodic Check ===');
//       print('Peer connections: ${_peerConnections.length}');
//       _peerConnections.forEach((userId, pc) {
//         print('Peer $userId - ICE state: ${pc.iceConnectionState}');
//       });
//     });
//   }
//
//   void _startCallTimer() {
//     _callStartTime = DateTime.now();
//     _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (_callStartTime != null && mounted) {
//         final duration = DateTime.now().difference(_callStartTime!);
//         setState(() {
//           callDuration = _formatDuration(duration);
//         });
//       }
//     });
//   }
//
//   String _formatDuration(Duration duration) {
//     String twoDigits(int n) => n.toString().padLeft(2, '0');
//     final hours = duration.inHours;
//     final minutes = duration.inMinutes.remainder(60);
//     final seconds = duration.inSeconds.remainder(60);
//     return hours > 0
//         ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}'
//         : '${twoDigits(minutes)}:${twoDigits(seconds)}';
//   }
//
//   Future<void> _requestPermissions() async {
//     print('Requesting permissions...');
//     setState(() {
//       connectionStatus = 'Requesting permissions...';
//     });
//
//     Map<Permission, PermissionStatus> permissions = await [
//       Permission.camera,
//       Permission.microphone,
//     ].request();
//
//     bool allGranted = permissions.values.every((status) => status.isGranted);
//
//     if (allGranted) {
//       print('All permissions granted, proceeding with initialization...');
//       try {
//         await _initRenderers();
//         await _startCall();
//       } catch (e, stackTrace) {
//         print('Error in initialization: $e\nStack trace: $stackTrace');
//         setState(() {
//           connectionStatus = 'Initialization failed';
//           isConnecting = false;
//         });
//         _showErrorDialog('Failed to initialize video call', e.toString());
//       }
//     } else {
//       print('Permissions denied: $permissions');
//       setState(() {
//         connectionStatus = 'Permissions required';
//         isConnecting = false;
//       });
//       await _showPermissionDialog();
//       if (await Permission.camera.isGranted && await Permission.microphone.isGranted) {
//         await _initRenderers();
//         await _startCall();
//       }
//     }
//   }
//
//   Future<void> _showErrorDialog(String title, String message) async {
//     return showDialog<void>(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           backgroundColor: Colors.grey[900],
//           title: Text(title, style: const TextStyle(color: Colors.white)),
//           content: Text(message, style: const TextStyle(color: Colors.white70)),
//           actions: [
//             TextButton(
//               child: const Text('OK', style: TextStyle(color: Colors.blue)),
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 Navigator.of(context).pop();
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   Future<void> _showPermissionDialog() async {
//     return showDialog<void>(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           backgroundColor: Colors.grey[900],
//           title: const Text('Permissions Required', style: TextStyle(color: Colors.white)),
//           content: const Text(
//             'Camera and microphone permissions are required for video calls.',
//             style: TextStyle(color: Colors.white70),
//           ),
//           actions: [
//             TextButton(
//               child: const Text('Exit', style: TextStyle(color: Colors.grey)),
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 Navigator.of(context).pop();
//               },
//             ),
//             TextButton(
//               child: const Text('Grant Permissions', style: TextStyle(color: Colors.blue)),
//               onPressed: () async {
//                 Navigator.of(context).pop();
//                 await openAppSettings();
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   Future<void> _initRenderers() async {
//     print('Initializing local renderer...');
//     setState(() {
//       connectionStatus = 'Setting up video...';
//     });
//     await _localRenderer.initialize();
//     print('Local renderer initialized: ${_localRenderer.textureId}');
//   }
//
//   Future<void> _startCall() async {
//     setState(() {
//       isConnecting = true;
//       connectionStatus = 'Connecting...';
//     });
//
//     try {
//       await _setupLocalStream();
//       await _setupSignaling();
//       await _joinRoom();
//     } catch (e, stackTrace) {
//       print('Error starting call: $e\nStack trace: $stackTrace');
//       setState(() {
//         connectionStatus = 'Connection failed';
//         isConnecting = false;
//       });
//       await _cleanup();
//       _showErrorDialog('Connection Failed', 'Unable to establish connection.');
//     }
//   }
//
//   Future<void> _joinRoom() async {
//     final roomRef = FirebaseFirestore.instance.collection('rooms').doc('group').collection(widget.roomId).doc(widget.roomId);
//     await roomRef.set({'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
//     await roomRef.collection('participants').doc(widget.userId).set({
//       'joinedAt': FieldValue.serverTimestamp(),
//       'status': 'active',
//     });
//     print('User ${widget.userId} joined group room ${widget.roomId}');
//   }
//
//   Future<void> _setupLocalStream() async {
//     print('Setting up local stream...');
//     setState(() {
//       connectionStatus = 'Accessing camera...';
//     });
//
//     try {
//       _localStream = await navigator.mediaDevices.getUserMedia({
//         'audio': true,
//         'video': {
//           'facingMode': 'user',
//           'width': {'min': 320, 'ideal': 640, 'max': 1280},
//           'height': {'min': 240, 'ideal': 480, 'max': 720},
//           'frameRate': {'min': 15, 'ideal': 24, 'max': 30},
//         },
//       });
//       print('Local stream created with ID: ${_localStream!.id}');
//       print('Video tracks: ${_localStream!.getVideoTracks().length}');
//       print('Audio tracks: ${_localStream!.getAudioTracks().length}');
//       if (_localStream!.getVideoTracks().isEmpty) {
//         print('Warning: No video track in local stream');
//         _showQuickFeedback('No camera detected. Please check permissions.');
//       }
//       setState(() {
//         _localRenderer.srcObject = _localStream;
//       });
//     } catch (e) {
//       print('Error setting up local stream: $e');
//       _showErrorDialog('Camera Error', 'Failed to access camera: $e');
//       rethrow;
//     }
//   }
//
//   Future<void> _setupLocalStream1() async {
//     print('Setting up local stream...');
//     setState(() {
//       connectionStatus = 'Accessing camera...';
//     });
//
//     try {
//       _localStream = await navigator.mediaDevices.getUserMedia({
//         'audio': true,
//         'video': {
//           'facingMode': 'user',
//           'width': {'min': 320, 'ideal': 640, 'max': 1280},
//           'height': {'min': 240, 'ideal': 480, 'max': 720},
//           'frameRate': {'min': 15, 'ideal': 24, 'max': 30},
//         },
//       });
//       print('Local stream created with ID: ${_localStream!.id}');
//       print('Video tracks: ${_localStream!.getVideoTracks().length}');
//       print('Audio tracks: ${_localStream!.getAudioTracks().length}');
//       setState(() {
//         _localRenderer.srcObject = _localStream;
//       });
//     } catch (e) {
//       print('Error setting up local stream: $e');
//       rethrow;
//     }
//   }
//
//   Future<void> _createPeerConnection(String remoteUserId) async {
//     if (_peerConnections.containsKey(remoteUserId)) {
//       print('Peer connection for $remoteUserId already exists');
//       return;
//     }
//
//     final config = {
//       'iceServers': [
//         {'urls': 'stun:stun.l.google.com:19302'},
//         {'urls': 'stun:stun1.l.google.com:19302'},
//         {
//           'urls': 'turn:openrelay.metered.ca:80',
//           'username': 'openrelayproject',
//           'credential': 'openrelayproject',
//         },
//       ],
//       'iceCandidatePoolSize': 10,
//       'bundlePolicy': 'max-bundle',
//       'rtcpMuxPolicy': 'require',
//       'iceTransportPolicy': 'all',
//     };
//
//     print('Creating peer connection for $remoteUserId');
//     final pc = await createPeerConnection(config);
//     _peerConnections[remoteUserId] = pc;
//
//     final renderer = RTCVideoRenderer();
//     await renderer.initialize();
//     _remoteRenderers[remoteUserId] = renderer;
//
//     if (_localStream != null) {
//       for (var track in _localStream!.getTracks()) {
//         await pc.addTrack(track, _localStream!);
//         print('Added track ${track.kind} to peer connection for $remoteUserId');
//       }
//     } else {
//       print('Warning: Local stream is null when adding tracks for $remoteUserId');
//     }
//
//     pc.onIceConnectionState = (state) {
//       print('ICE Connection State for $remoteUserId: $state');
//       setState(() {
//         if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
//             state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
//           connectionStatus = 'Connected';
//           isConnecting = false;
//           if (_callStartTime == null) _startCallTimer();
//         } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
//           connectionStatus = 'Reconnecting...';
//         } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
//           connectionStatus = 'Connection failed';
//           print('Restarting ICE for $remoteUserId');
//           pc.restartIce();
//         }
//       });
//     };
//
//     pc.onTrack = (event) {
//       print('OnTrack for $remoteUserId: Stream count: ${event.streams.length}, Track count: ${event.streams.isNotEmpty ? event.streams[0].getTracks().length : 0}');
//       if (event.streams.isNotEmpty) {
//         final stream = event.streams[0];
//         print('Remote stream ID: ${stream.id}, Video tracks: ${stream.getVideoTracks().length}, Audio tracks: ${stream.getAudioTracks().length}');
//         setState(() {
//           _remoteRenderers[remoteUserId]!.srcObject = null; // Reset renderer
//           _remoteRenderers[remoteUserId]!.srcObject = stream; // Set new stream
//         });
//       } else {
//         print('No streams received in onTrack for $remoteUserId');
//       }
//     };
//
//     pc.onIceCandidate = (candidate) {
//       if (candidate.candidate == null) return;
//       print('Sending ICE candidate for $remoteUserId: ${candidate.candidate}');
//       final roomRef = FirebaseFirestore.instance.collection('rooms').doc('group').collection(widget.roomId).doc(widget.roomId);
//       roomRef
//           .collection('signals')
//           .doc(widget.userId)
//           .collection('to_$remoteUserId')
//           .add({
//         'candidate': candidate.candidate,
//         'sdpMid': candidate.sdpMid,
//         'sdpMLineIndex': candidate.sdpMLineIndex,
//       }).then((_) => print('ICE candidate sent for $remoteUserId')).catchError((e) {
//         print('Error sending ICE candidate for $remoteUserId: $e');
//       });
//     };
//
//     try {
//       final offer = await pc.createOffer({
//         'offerToReceiveAudio': true,
//         'offerToReceiveVideo': true,
//       });
//       await pc.setLocalDescription(offer);
//       print('Local description set for $remoteUserId: ${offer.sdp}');
//       final roomRef = FirebaseFirestore.instance.collection('rooms').doc('group').collection(widget.roomId).doc(widget.roomId);
//       await roomRef.collection('signals').doc(widget.userId).set({
//         'to_$remoteUserId': offer.toMap(),
//       }, SetOptions(merge: true));
//       print('Offer sent to $remoteUserId');
//     } catch (e) {
//       print('Error creating/sending offer for $remoteUserId: $e');
//       _showErrorDialog('Signaling Error', 'Failed to send offer: $e');
//     }
//   }
//
//
//   Future<void> _createPeerConnection1(String remoteUserId) async {
//     if (_peerConnections.containsKey(remoteUserId)) {
//       print('Peer connection for $remoteUserId already exists');
//       return;
//     }
//
//     final config = {
//       'iceServers': [
//         {'urls': 'stun:stun.l.google.com:19302'},
//         {'urls': 'stun:stun1.l.google.com:19302'},
//         {
//           'urls': 'turn:openrelay.metered.ca:80',
//           'username': 'openrelayproject',
//           'credential': 'openrelayproject',
//         },
//       ],
//       'iceCandidatePoolSize': 10,
//       'bundlePolicy': 'max-bundle',
//       'rtcpMuxPolicy': 'require',
//       'iceTransportPolicy': 'all',
//     };
//
//     print('Creating peer connection for $remoteUserId');
//     final pc = await createPeerConnection(config);
//     _peerConnections[remoteUserId] = pc;
//
//     final renderer = RTCVideoRenderer();
//     await renderer.initialize();
//     _remoteRenderers[remoteUserId] = renderer;
//
//     // Add local stream tracks to the peer connection
//     if (_localStream != null) {
//       for (var track in _localStream!.getTracks()) {
//         await pc.addTrack(track, _localStream!);
//         print('Added track ${track.kind} to peer connection for $remoteUserId');
//       }
//     } else {
//       print('Warning: Local stream is null when adding tracks for $remoteUserId');
//     }
//
//     pc.onIceConnectionState = (state) {
//       print('ICE Connection State for $remoteUserId: $state');
//       setState(() {
//         if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
//             state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
//           connectionStatus = 'Connected';
//           isConnecting = false;
//           if (_callStartTime == null) _startCallTimer();
//         } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
//           connectionStatus = 'Reconnecting...';
//         } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
//           connectionStatus = 'Connection failed';
//           print('Restarting ICE for $remoteUserId');
//           pc.restartIce();
//         }
//       });
//     };
//
//     pc.onTrack = (event) {
//       print('OnTrack for $remoteUserId: Stream count: ${event.streams.length}, Track count: ${event.streams.isNotEmpty ? event.streams[0].getTracks().length : 0}');
//       if (event.streams.isNotEmpty) {
//         final stream = event.streams[0];
//         print('Remote stream ID: ${stream.id}, Video tracks: ${stream.getVideoTracks().length}, Audio tracks: ${stream.getAudioTracks().length}');
//         setState(() {
//           _remoteRenderers[remoteUserId]!.srcObject = stream;
//         });
//       } else {
//         print('No streams received in onTrack for $remoteUserId');
//       }
//     };
//
//     // pc.onTrack = (event) {
//     //   print('OnTrack for $remoteUserId: Stream count: ${event.streams.length}, Track count: ${event.streams.isNotEmpty ? event.streams[0].getTracks().length : 0}');
//     //   if (event.streams.isNotEmpty) {
//     //     final stream = event.streams[0];
//     //     print('Remote stream ID: ${stream.id}, Video tracks: ${stream.getVideoTracks().length}, Audio tracks: ${stream.getAudioTracks().length}');
//     //     setState(() {
//     //       _remoteRenderers[remoteUserId]!.srcObject = stream;
//     //     });
//     //   } else {
//     //     print('No streams received in onTrack for $remoteUserId');
//     //   }
//     // };
//
//     pc.onIceCandidate = (candidate) {
//       if (candidate.candidate == null) return;
//       print('Sending ICE candidate for $remoteUserId: ${candidate.candidate}');
//       final roomRef = FirebaseFirestore.instance.collection('rooms').doc('group').collection(widget.roomId).doc(widget.roomId);
//       roomRef
//           .collection('signals')
//           .doc(widget.userId)
//           .collection('to_$remoteUserId')
//           .add({
//         'candidate': candidate.candidate,
//         'sdpMid': candidate.sdpMid,
//         'sdpMLineIndex': candidate.sdpMLineIndex,
//       }).then((_) => print('ICE candidate sent for $remoteUserId'));
//     };
//
//     final offer = await pc.createOffer({
//       'offerToReceiveAudio': true,
//       'offerToReceiveVideo': true,
//     });
//     await pc.setLocalDescription(offer);
//     print('Local description set for $remoteUserId: ${offer.sdp}');
//     final roomRef = FirebaseFirestore.instance.collection('rooms').doc('group').collection(widget.roomId).doc(widget.roomId);
//     await roomRef.collection('signals').doc(widget.userId).set({
//       'to_$remoteUserId': offer.toMap(),
//     }, SetOptions(merge: true));
//     print('Offer sent to $remoteUserId');
//   }
//
//   Future<void> _setupSignaling() async {
//     final roomRef = FirebaseFirestore.instance.collection('rooms').doc('group').collection(widget.roomId).doc(widget.roomId);
//
//     _participantsSub = roomRef.collection('participants').snapshots().listen((snapshot) async {
//       print('Participants snapshot received');
//       final currentParticipants = snapshot.docs.map((doc) => doc.id).toList();
//       print('Participants updated: $currentParticipants');
//
//       if (currentParticipants.length > 5) {
//         _showErrorDialog('Room Full', 'Maximum 5 participants allowed.');
//         await _hangUp();
//         return;
//       }
//
//       for (var remoteUserId in currentParticipants) {
//         if (remoteUserId == widget.userId) continue;
//         if (!_peerConnections.containsKey(remoteUserId)) {
//           await _createPeerConnection(remoteUserId);
//         }
//       }
//
//       _peerConnections.keys.toList().forEach((userId) {
//         if (userId != widget.userId && !currentParticipants.contains(userId)) {
//           _removePeer(userId);
//         }
//       });
//     });
//
//     _roomSub = roomRef.collection('signals').doc(widget.userId).snapshots().listen((snapshot) async {
//       final data = snapshot.data();
//       print('Received signal for ${widget.userId}: $data');
//       if (data == null) return;
//
//       for (var remoteUserId in data.keys.where((key) => key.startsWith('to_'))) {
//         final targetUserId = remoteUserId.replaceFirst('to_', '');
//         if (!_peerConnections.containsKey(targetUserId)) {
//           print('No peer connection for $targetUserId, skipping signal');
//           continue;
//         }
//
//         final pc = _peerConnections[targetUserId]!;
//         final signal = data[remoteUserId] as Map<String, dynamic>?;
//
//         if (signal != null && signal['type'] == 'offer' && await pc.getRemoteDescription() == null) {
//           print('Processing offer from $targetUserId: ${signal['sdp']}');
//           await pc.setRemoteDescription(RTCSessionDescription(signal['sdp'], signal['type']));
//           final answer = await pc.createAnswer({
//             'offerToReceiveAudio': true,
//             'offerToReceiveVideo': true,
//           });
//           await pc.setLocalDescription(answer);
//           print('Answer created for $targetUserId: ${answer.sdp}');
//           await roomRef.collection('signals').doc(targetUserId).set({
//             'to_${widget.userId}': answer.toMap(),
//           }, SetOptions(merge: true));
//           print('Answer sent to $targetUserId');
//           await _flushRemoteCandidates(targetUserId);
//         } else if (signal != null && signal['type'] == 'answer' && await pc.getRemoteDescription() == null) {
//           print('Processing answer from $targetUserId: ${signal['sdp']}');
//           await pc.setRemoteDescription(RTCSessionDescription(signal['sdp'], signal['type']));
//           await _flushRemoteCandidates(targetUserId);
//         }
//       }
//     });
//
//     roomRef.collection('signals').snapshots().listen((snapshot) {
//       for (var doc in snapshot.docChanges) {
//         if (doc.type == DocumentChangeType.added && doc.doc.id != widget.userId) {
//           doc.doc.reference.collection('to_${widget.userId}').snapshots().listen((candidateSnapshot) {
//             for (var candidateDoc in candidateSnapshot.docChanges) {
//               if (candidateDoc.type == DocumentChangeType.added) {
//                 _handleRemoteCandidate(doc.doc.id, candidateDoc.doc.data()!);
//               }
//             }
//           });
//         }
//       }
//     });
//   }
//
//   void _handleRemoteCandidate(String remoteUserId, Map<String, dynamic> data) async {
//     final candidate = data['candidate'] as String?;
//     final sdpMid = data['sdpMid'] as String?;
//     final sdpMLineIndex = data['sdpMLineIndex'] is int ? data['sdpMLineIndex'] as int : int.tryParse('${data['sdpMLineIndex']}');
//
//     if (candidate == null || sdpMid == null || sdpMLineIndex == null) {
//       print('Invalid candidate data from $remoteUserId: $data');
//       return;
//     }
//
//     final rtcCandidate = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
//     if (_peerConnections.containsKey(remoteUserId)) {
//       final pc = _peerConnections[remoteUserId]!;
//       if (await pc.getRemoteDescription() == null) {
//         _remoteCandidateBuffers.putIfAbsent(remoteUserId, () => []).add(rtcCandidate);
//         print('Buffered candidate for $remoteUserId: $candidate');
//       } else {
//         await pc.addCandidate(rtcCandidate);
//         print('Added candidate for $remoteUserId: $candidate');
//       }
//     } else {
//       print('No peer connection for $remoteUserId, discarding candidate');
//     }
//   }
//
//   Future<void> _flushRemoteCandidates(String remoteUserId) async {
//     if (_remoteCandidateBuffers.containsKey(remoteUserId)) {
//       print('Flushing ${(_remoteCandidateBuffers[remoteUserId]?.length ?? 0)} candidates for $remoteUserId');
//       for (var candidate in _remoteCandidateBuffers[remoteUserId]!) {
//         await _peerConnections[remoteUserId]?.addCandidate(candidate);
//         print('Flushed candidate for $remoteUserId: ${candidate.candidate}');
//       }
//       _remoteCandidateBuffers.remove(remoteUserId);
//     }
//   }
//
//   void _removePeer(String userId) {
//     print('Removing peer $userId');
//     _peerConnections[userId]?.close();
//     _remoteRenderers[userId]?.dispose();
//     setState(() {
//       _peerConnections.remove(userId);
//       _remoteRenderers.remove(userId);
//       _remoteCandidateBuffers.remove(userId);
//     });
//   }
//
//   Future<void> _toggleMute() async {
//     if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
//       final audioTrack = _localStream!.getAudioTracks().first;
//       audioTrack.enabled = !audioTrack.enabled;
//       setState(() {
//         isMuted = !audioTrack.enabled;
//       });
//       _showQuickFeedback(isMuted ? 'Microphone off' : 'Microphone on');
//     } else {
//       print('No audio track available to toggle mute');
//     }
//   }
//
//   Future<void> _toggleVideo() async {
//     if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
//       final videoTrack = _localStream!.getVideoTracks().first;
//       videoTrack.enabled = !videoTrack.enabled;
//       setState(() {
//         isVideoOff = !videoTrack.enabled;
//       });
//       _showQuickFeedback(isVideoOff ? 'Camera off' : 'Camera on');
//     } else {
//       print('No video track available to toggle video');
//     }
//   }
//
//   Future<void> _switchCamera() async {
//     if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
//       final videoTrack = _localStream!.getVideoTracks().first;
//       try {
//         await videoTrack.switchCamera();
//         setState(() {
//           isRearCamera = !isRearCamera;
//         });
//         _showQuickFeedback('Switched to ${isRearCamera ? "rear" : "front"} camera');
//       } catch (e) {
//         print('Error switching camera: $e');
//         _showQuickFeedback('Unable to switch camera');
//       }
//     } else {
//       print('No video track available to switch camera');
//     }
//   }
//
//   void _showQuickFeedback(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message, style: const TextStyle(color: Colors.white)),
//         backgroundColor: Colors.black87,
//         duration: const Duration(seconds: 1),
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//         margin: const EdgeInsets.only(bottom: 120, left: 20, right: 20),
//       ),
//     );
//   }
//
//   Future<void> _hangUp() async {
//     await _cleanup();
//     Navigator.of(context).pop();
//   }
//
//   Future<void> _cleanup() async {
//     print('Cleaning up resources...');
//     try {
//       _roomSub?.cancel();
//       _participantsSub?.cancel();
//       _debugTimer?.cancel();
//       _callTimer?.cancel();
//       _pulseController.dispose();
//
//       _localStream?.getTracks().forEach((track) => track.stop());
//       _localRenderer.srcObject = null;
//       await _localRenderer.dispose();
//
//       for (var entry in _peerConnections.entries) {
//         await entry.value.close();
//       }
//       for (var entry in _remoteRenderers.entries) {
//         entry.value.srcObject?.getTracks().forEach((track) => track.stop());
//         await entry.value.dispose();
//       }
//
//       _peerConnections.clear();
//       _remoteRenderers.clear();
//       _remoteCandidateBuffers.clear();
//
//       final roomRef = FirebaseFirestore.instance.collection('rooms').doc('group').collection(widget.roomId).doc(widget.roomId);
//       await roomRef.collection('participants').doc(widget.userId).delete();
//
//       setState(() {
//         isConnecting = false;
//         connectionStatus = 'Call ended';
//       });
//     } catch (e) {
//       print('Error during cleanup: $e');
//     }
//   }
//
//   @override
//   void dispose() {
//     print('Disposing GroupChatRoom...');
//     _cleanup();
//     super.dispose();
//   }
//
//   Widget _buildStatusBar() {
//     Color statusColor = isConnecting
//         ? Colors.orange
//         : _peerConnections.isNotEmpty
//         ? Colors.green
//         : Colors.red;
//     IconData statusIcon = isConnecting
//         ? Icons.sync
//         : _peerConnections.isNotEmpty
//         ? Icons.check_circle
//         : Icons.error_outline;
//
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//           colors: [Colors.black.withOpacity(0.8), Colors.transparent],
//         ),
//       ),
//       child: SafeArea(
//         child: Row(
//           children: [
//             AnimatedBuilder(
//               animation: _pulseAnimation,
//               builder: (context, child) {
//                 return Transform.scale(
//                   scale: isConnecting ? _pulseAnimation.value : 1.0,
//                   child: Icon(statusIcon, color: statusColor, size: 20),
//                 );
//               },
//             ),
//             const SizedBox(width: 8),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(
//                     connectionStatus,
//                     style: TextStyle(
//                       color: statusColor,
//                       fontSize: 14,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                   if (_peerConnections.isNotEmpty && callDuration != '00:00')
//                     Text(
//                       callDuration,
//                       style: const TextStyle(color: Colors.white70, fontSize: 12),
//                     ),
//                 ],
//               ),
//             ),
//             GestureDetector(
//               onTap: () => ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text('Room ID: ${widget.roomId} copied')),
//               ),
//               child: Row(
//                 children: [
//                   Text(
//                     'Room: ${widget.roomId}',
//                     style: const TextStyle(color: Colors.white54, fontSize: 14),
//                   ),
//                   const Icon(Icons.copy, color: Colors.white54, size: 18),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLocalVideoView() {
//     return Container(
//       width: 120,
//       height: 160,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.blue, width: 2),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.3),
//             blurRadius: 8,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(11),
//         child: Stack(
//           children: [
//             if (!isVideoOff && _localRenderer.srcObject != null)
//               RTCVideoView(
//                 _localRenderer,
//                 key: ValueKey('local_${_localRenderer.srcObject?.id}'),
//                 mirror: !isRearCamera,
//                 objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
//                 filterQuality: FilterQuality.medium,
//               )
//             else
//               Container(
//                 color: Colors.grey[900],
//                 child: const Center(
//                   child: Icon(Icons.videocam_off, color: Colors.white54, size: 32),
//                 ),
//               ),
//             if (isMuted)
//               Positioned(
//                 bottom: 8,
//                 right: 8,
//                 child: Container(
//                   padding: const EdgeInsets.all(4),
//                   decoration: BoxDecoration(
//                     color: Colors.red.withOpacity(0.8),
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: const Icon(Icons.mic_off, color: Colors.white, size: 12),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildRemoteVideoView(String userId, RTCVideoRenderer renderer) {
//     return Container(
//       width: MediaQuery.of(context).size.width / 2 - 16,
//       height: 200,
//       margin: const EdgeInsets.all(8),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.white.withOpacity(0.3)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.3),
//             blurRadius: 8,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(11),
//         child: renderer.srcObject != null && renderer.srcObject!.getVideoTracks().isNotEmpty
//             ? RTCVideoView(
//           renderer,
//           key: ValueKey('remote_$userId'),
//           objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
//           filterQuality: FilterQuality.medium,
//         )
//             : Container(
//           color: Colors.black,
//           child: Center(
//             child: Text(
//               'User $userId\n(No video stream)', textAlign: TextAlign.center,
//               style: const TextStyle(color: Colors.white54, fontSize: 14,),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildRemoteVideoView1(String userId, RTCVideoRenderer renderer) {
//     return Container(
//       width: MediaQuery.of(context).size.width / 2 - 16,
//       height: 200,
//       margin: const EdgeInsets.all(8),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.white.withOpacity(0.3)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.3),
//             blurRadius: 8,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(11),
//         child: renderer.srcObject != null && renderer.srcObject!.getVideoTracks().isNotEmpty
//             ? RTCVideoView(
//           renderer,
//           key: ValueKey('remote_$userId'),
//           objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
//           filterQuality: FilterQuality.medium,
//         )
//             : Container(
//           color: Colors.black,
//           child: Center(
//             child: Text(
//               'User $userId\n(No video stream)',textAlign: TextAlign.center,
//               style: const TextStyle(color: Colors.white54, fontSize: 14, ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildControlButtons() {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.bottomCenter,
//           end: Alignment.topCenter,
//           colors: [Colors.black.withOpacity(0.9), Colors.transparent],
//         ),
//       ),
//       child: SafeArea(
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             _buildControlButton(
//               icon: isMuted ? Icons.mic_off : Icons.mic,
//               onPressed: _toggleMute,
//               backgroundColor: isMuted ? Colors.red : Colors.white.withOpacity(0.2),
//               iconColor: isMuted ? Colors.white : Colors.white,
//             ),
//             _buildControlButton(
//               icon: isVideoOff ? Icons.videocam_off : Icons.videocam,
//               onPressed: _toggleVideo,
//               backgroundColor: isVideoOff ? Colors.red : Colors.white.withOpacity(0.2),
//               iconColor: isVideoOff ? Colors.white : Colors.white,
//             ),
//             _buildControlButton(
//               icon: Icons.call_end,
//               onPressed: _hangUp,
//               backgroundColor: Colors.red,
//               iconColor: Colors.white,
//               isLarge: true,
//             ),
//             _buildControlButton(
//               icon: Icons.flip_camera_ios,
//               onPressed: _switchCamera,
//               backgroundColor: Colors.white.withOpacity(0.2),
//               iconColor: Colors.white,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildControlButton({
//     required IconData icon,
//     required VoidCallback onPressed,
//     required Color backgroundColor,
//     required Color iconColor,
//     bool isLarge = false,
//   }) {
//     final size = isLarge ? 64.0 : 52.0;
//     final iconSize = isLarge ? 28.0 : 24.0;
//     return GestureDetector(
//       onTap: onPressed,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 150),
//         width: size,
//         height: size,
//         decoration: BoxDecoration(
//           color: backgroundColor,
//           borderRadius: BorderRadius.circular(size / 2),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.3),
//               blurRadius: 8,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Icon(icon, color: iconColor, size: iconSize),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Container(
//         height: MediaQuery.of(context).size.height,
//         child: Stack(
//           children: [
//             Positioned.fill(
//               top: 80,
//               bottom: 120,
//               child: _remoteRenderers.isEmpty
//                   ? Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     AnimatedBuilder(
//                       animation: _pulseAnimation,
//                       builder: (context, child) {
//                         return Transform.scale(
//                           scale: isConnecting ? _pulseAnimation.value : 1.0,
//                           child: Container(
//                             width: 120,
//                             height: 120,
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.1),
//                               borderRadius: BorderRadius.circular(60),
//                               border: Border.all(
//                                 color: Colors.white.withOpacity(0.3),
//                                 width: 2,
//                               ),
//                             ),
//                             child: const Icon(
//                               Icons.person,
//                               size: 60,
//                               color: Colors.white54,
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                     const SizedBox(height: 24),
//                     Text(
//                       isConnecting ? 'Connecting...' : 'Waiting for participants',
//                       style: const TextStyle(
//                         color: Colors.white70,
//                         fontSize: 18,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ],
//                 ),
//               )
//                   : GridView.builder(
//                 padding: const EdgeInsets.all(8),
//                 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                   crossAxisCount: 2,
//                   childAspectRatio: 0.75,
//                   crossAxisSpacing: 8,
//                   mainAxisSpacing: 8,
//                 ),
//                 itemCount: _remoteRenderers.length,
//                 itemBuilder: (context, index) {
//                   final userId = _remoteRenderers.keys.elementAt(index);
//                   return _buildRemoteVideoView(userId, _remoteRenderers[userId]!);
//                 },
//               ),
//             ),
//             _buildStatusBar(),
//             if (_localRenderer.srcObject != null)
//               Positioned(
//                 top: 100,
//                 right: 16,
//                 child: _buildLocalVideoView(),
//               ),
//             Positioned(
//               left: 0,
//               right: 0,
//               bottom: 0,
//               child: _buildControlButtons(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

class GroupChatRoom extends StatefulWidget {
  final String roomId;
  final String userId;
  const GroupChatRoom({super.key, required this.roomId, required this.userId});

  @override
  State<GroupChatRoom> createState() => _GroupChatRoomState();
}

class _GroupChatRoomState extends State<GroupChatRoom> with TickerProviderStateMixin {
  final _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final Map<String, RTCPeerConnection> _peerConnections = {};
  MediaStream? _localStream;

  bool isConnecting = false;
  bool isMuted = false;
  bool isVideoOff = false;
  bool isRearCamera = false;
  String connectionStatus = 'Initializing...';
  String callDuration = '00:00';

  final Map<String, List<RTCIceCandidate>> _remoteCandidateBuffers = {};
  final Map<String, StreamSubscription> _signalSubscriptions = {};
  StreamSubscription<QuerySnapshot>? _participantsSub;
  Timer? _debugTimer;
  Timer? _callTimer;
  DateTime? _callStartTime;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    print('GroupChatRoom initState - Starting initialization for user ${widget.userId}');

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _requestPermissions();

    _debugTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      print('=== Debug Info ===');
      print('Total peer connections: ${_peerConnections.length}');
      print('Total remote renderers: ${_remoteRenderers.length}');
      _peerConnections.forEach((userId, pc) async {
        final iceState = pc.iceConnectionState;
        final localDesc = await pc.getLocalDescription();
        final remoteDesc = await pc.getRemoteDescription();
        print('$userId: ICE=$iceState, Local=${localDesc?.type}, Remote=${remoteDesc?.type}');
      });
      _remoteRenderers.forEach((userId, renderer) {
        final hasStream = renderer.srcObject != null;
        final hasVideo = hasStream ? renderer.srcObject!.getVideoTracks().isNotEmpty : false;
        print('$userId renderer: stream=$hasStream, video=$hasVideo');
      });
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
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _initRenderers() async {
    print('Initializing local renderer...');
    setState(() {
      connectionStatus = 'Setting up video...';
    });
    await _localRenderer.initialize();
    print('Local renderer initialized: ${_localRenderer.textureId}');
  }

  Future<void> _startCall() async {
    setState(() {
      isConnecting = true;
      connectionStatus = 'Connecting...';
    });

    try {
      await _setupLocalStream();
      await _joinRoom();
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

  Future<void> _joinRoom() async {
    final roomRef = _getRoomRef();

    // Create room if it doesn't exist
    await roomRef.set({'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

    // Add this user as a participant
    await roomRef.collection('participants').doc(widget.userId).set({
      'joinedAt': FieldValue.serverTimestamp(),
      'status': 'active',
      'userId': widget.userId,
    });

    print('User ${widget.userId} joined room ${widget.roomId}');
  }

  DocumentReference _getRoomRef() {
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId);
  }

  Future<void> _setupLocalStream() async {
    print('Setting up local stream...');
    setState(() {
      connectionStatus = 'Accessing camera...';
    });

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'min': 320, 'ideal': 640, 'max': 1280},
          'height': {'min': 240, 'ideal': 480, 'max': 720},
          'frameRate': {'min': 15, 'ideal': 30, 'max': 30},
        },
      });

      print('Local stream created: ${_localStream!.id}');
      print('Video tracks: ${_localStream!.getVideoTracks().length}');
      print('Audio tracks: ${_localStream!.getAudioTracks().length}');

      if (_localStream!.getVideoTracks().isEmpty) {
        throw Exception('No video track available');
      }

      setState(() {
        _localRenderer.srcObject = _localStream;
      });

      print('Local stream setup complete');
    } catch (e) {
      print('Error setting up local stream: $e');
      rethrow;
    }
  }

  Future<void> _setupSignaling() async {
    final roomRef = _getRoomRef();

    // Listen for participants changes
    _participantsSub = roomRef.collection('participants')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen(_onParticipantsChanged);

    // Set up signal listeners
    _setupOfferListener();
    _setupAnswerListener();
    _setupCandidateListener();

    print('Signaling setup complete');
  }

  Future<void> _onParticipantsChanged(QuerySnapshot snapshot) async {
    print('Participants changed: ${snapshot.docs.length} total');

    final participants = snapshot.docs.map((doc) => doc.id).toList();
    print('Active participants: $participants');

    if (participants.length > 5) {
      _showErrorDialog('Room Full', 'Maximum 5 participants allowed.');
      await _hangUp();
      return;
    }

    // Create peer connections for new participants
    for (final participantId in participants) {
      if (participantId != widget.userId && !_peerConnections.containsKey(participantId)) {
        print('New participant detected: $participantId');
        await _createPeerConnectionFor(participantId);

        // Determine who should initiate the call based on user ID comparison
        // This prevents both users from sending offers simultaneously
        if (widget.userId.compareTo(participantId) < 0) {
          print('${widget.userId} will initiate call to $participantId');
          await _sendOfferTo(participantId);
        } else {
          print('${widget.userId} will wait for offer from $participantId');
        }
      }
    }

    // Remove connections for participants who left
    final participantsToRemove = _peerConnections.keys
        .where((userId) => !participants.contains(userId))
        .toList();

    for (final userId in participantsToRemove) {
      print('Participant left: $userId');
      _removePeer(userId);
    }

    // Update UI
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _createPeerConnectionFor(String remoteUserId) async {
    print('Creating peer connection for $remoteUserId');

    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {
          'urls': 'turn:openrelay.metered.ca:80',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
      ],
      'iceCandidatePoolSize': 10,
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    };

    final pc = await createPeerConnection(config);
    _peerConnections[remoteUserId] = pc;

    // Initialize remote renderer
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    _remoteRenderers[remoteUserId] = renderer;

    // Add local stream tracks
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
        print('Added ${track.kind} track to peer connection for $remoteUserId');
      }
    }

    // Set up event handlers
    pc.onIceConnectionState = (state) {
      print('ICE state for $remoteUserId: $state');
      if (mounted) {
        setState(() {
          if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
              state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
            connectionStatus = 'Connected';
            isConnecting = false;
            if (_callStartTime == null) _startCallTimer();
          } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
            connectionStatus = 'Reconnecting...';
          } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
            connectionStatus = 'Connection failed';
            print('ICE connection failed for $remoteUserId, restarting ICE');
            pc.restartIce();
          }
        });
      }
    };

    pc.onTrack = (event) {
      print('Received track from $remoteUserId: ${event.track.kind}');
      print('Streams received: ${event.streams.length}');

      if (event.streams.isNotEmpty) {
        final stream = event.streams.first;
        print('Remote stream: ${stream.id}, video tracks: ${stream.getVideoTracks().length}');

        if (mounted) {
          setState(() {
            _remoteRenderers[remoteUserId]!.srcObject = stream;
          });
        }
        print('Set remote stream for $remoteUserId');
      }
    };

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        print('Sending ICE candidate from ${widget.userId} to $remoteUserId');
        _sendIceCandidate(remoteUserId, candidate);
      }
    };

    print('Peer connection created for $remoteUserId');
  }

  Future<void> _sendOfferTo(String remoteUserId) async {
    final pc = _peerConnections[remoteUserId];
    if (pc == null) return;

    try {
      print('Creating offer for $remoteUserId');
      final offer = await pc.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });

      await pc.setLocalDescription(offer);
      print('Local description set for $remoteUserId');

      // Store offer in Firebase
      final roomRef = _getRoomRef();
      await roomRef.collection('offers').add({
        'from': widget.userId,
        'to': remoteUserId,
        'sdp': offer.sdp,
        'type': offer.type,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Offer sent to $remoteUserId');
    } catch (e) {
      print('Error sending offer to $remoteUserId: $e');
    }
  }

  void _setupOfferListener() {
    final roomRef = _getRoomRef();

    final offersSub = roomRef.collection('offers')
        .where('to', isEqualTo: widget.userId)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          _handleOffer(data, change.doc.id);
        }
      }
    });

    _signalSubscriptions['offers'] = offersSub;
  }

  void _setupAnswerListener() {
    final roomRef = _getRoomRef();

    final answersSub = roomRef.collection('answers')
        .where('to', isEqualTo: widget.userId)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          _handleAnswer(data, change.doc.id);
        }
      }
    });

    _signalSubscriptions['answers'] = answersSub;
  }

  void _setupCandidateListener() {
    final roomRef = _getRoomRef();

    final candidatesSub = roomRef.collection('candidates')
        .where('to', isEqualTo: widget.userId)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          _handleIceCandidate(data);
        }
      }
    });

    _signalSubscriptions['candidates'] = candidatesSub;
  }

  Future<void> _handleOffer(Map<String, dynamic> data, String docId) async {
    final fromUserId = data['from'] as String;
    final sdp = data['sdp'] as String;
    final type = data['type'] as String;

    print('Handling offer from $fromUserId');

    final pc = _peerConnections[fromUserId];
    if (pc == null) {
      print('No peer connection for $fromUserId');
      return;
    }

    try {
      // Check if remote description is already set
      if (await pc.getRemoteDescription() != null) {
        print('Remote description already set for $fromUserId, ignoring offer');
        await _deleteDocument('offers', docId);
        return;
      }

      await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
      print('Remote description set for $fromUserId');

      // Create answer
      final answer = await pc.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });

      await pc.setLocalDescription(answer);
      print('Local description (answer) set for $fromUserId');

      // Send answer
      final roomRef = _getRoomRef();
      await roomRef.collection('answers').add({
        'from': widget.userId,
        'to': fromUserId,
        'sdp': answer.sdp,
        'type': answer.type,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Answer sent to $fromUserId');

      // Process buffered ICE candidates
      await _processCandidateBuffer(fromUserId);

      // Delete the processed offer
      await _deleteDocument('offers', docId);

    } catch (e) {
      print('Error handling offer from $fromUserId: $e');
    }
  }

  Future<void> _handleAnswer(Map<String, dynamic> data, String docId) async {
    final fromUserId = data['from'] as String;
    final sdp = data['sdp'] as String;
    final type = data['type'] as String;

    print('Handling answer from $fromUserId');

    final pc = _peerConnections[fromUserId];
    if (pc == null) {
      print('No peer connection for $fromUserId');
      return;
    }

    try {
      // Check if remote description is already set
      if (await pc.getRemoteDescription() != null) {
        print('Remote description already set for $fromUserId, ignoring answer');
        await _deleteDocument('answers', docId);
        return;
      }

      await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
      print('Remote description (answer) set for $fromUserId');

      // Process buffered ICE candidates
      await _processCandidateBuffer(fromUserId);

      // Delete the processed answer
      await _deleteDocument('answers', docId);

    } catch (e) {
      print('Error handling answer from $fromUserId: $e');
    }
  }

  Future<void> _sendIceCandidate(String remoteUserId, RTCIceCandidate candidate) async {
    try {
      final roomRef = _getRoomRef();
      await roomRef.collection('candidates').add({
        'from': widget.userId,
        'to': remoteUserId,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('ICE candidate sent from ${widget.userId} to $remoteUserId');
    } catch (e) {
      print('Error sending ICE candidate to $remoteUserId: $e');
    }
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> data) async {
    final fromUserId = data['from'] as String;
    final candidateStr = data['candidate'] as String?;
    final sdpMid = data['sdpMid'] as String?;
    final sdpMLineIndex = data['sdpMLineIndex'] as int?;

    if (candidateStr == null || sdpMid == null || sdpMLineIndex == null) {
      print('Invalid ICE candidate data from $fromUserId');
      return;
    }

    final candidate = RTCIceCandidate(candidateStr, sdpMid, sdpMLineIndex);
    final pc = _peerConnections[fromUserId];

    if (pc == null) {
      print('No peer connection for ICE candidate from $fromUserId');
      return;
    }

    // Check if remote description is set
    if (await pc.getRemoteDescription() == null) {
      // Buffer the candidate
      _remoteCandidateBuffers.putIfAbsent(fromUserId, () => []).add(candidate);
      print('Buffered ICE candidate from $fromUserId (total: ${_remoteCandidateBuffers[fromUserId]!.length})');
    } else {
      // Add candidate immediately
      try {
        await pc.addCandidate(candidate);
        print('Added ICE candidate from $fromUserId');
      } catch (e) {
        print('Error adding ICE candidate from $fromUserId: $e');
      }
    }
  }

  Future<void> _processCandidateBuffer(String remoteUserId) async {
    final candidates = _remoteCandidateBuffers[remoteUserId];
    if (candidates == null || candidates.isEmpty) return;

    final pc = _peerConnections[remoteUserId];
    if (pc == null) return;

    print('Processing ${candidates.length} buffered candidates for $remoteUserId');

    for (final candidate in candidates) {
      try {
        await pc.addCandidate(candidate);
        print('Added buffered candidate for $remoteUserId');
      } catch (e) {
        print('Error adding buffered candidate for $remoteUserId: $e');
      }
    }

    _remoteCandidateBuffers.remove(remoteUserId);
    print('Finished processing candidates for $remoteUserId');
  }

  Future<void> _deleteDocument(String collection, String docId) async {
    try {
      final roomRef = _getRoomRef();
      await roomRef.collection(collection).doc(docId).delete();
      print('Deleted $collection document: $docId');
    } catch (e) {
      print('Error deleting $collection document $docId: $e');
    }
  }

  void _removePeer(String userId) {
    print('Removing peer: $userId');

    // Cancel subscriptions
    _signalSubscriptions.forEach((key, sub) {
      if (key.contains(userId)) {
        sub.cancel();
        _signalSubscriptions.remove(key);
      }
    });

    // Close peer connection
    _peerConnections[userId]?.close();
    _peerConnections.remove(userId);

    // Dispose renderer
    _remoteRenderers[userId]?.dispose();
    _remoteRenderers.remove(userId);

    // Clear candidate buffer
    _remoteCandidateBuffers.remove(userId);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleMute() async {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
      setState(() {
        isMuted = !audioTrack.enabled;
      });
      _showQuickFeedback(isMuted ? 'Microphone off' : 'Microphone on');
    }
  }

  Future<void> _toggleVideo() async {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      final videoTrack = _localStream!.getVideoTracks().first;
      videoTrack.enabled = !videoTrack.enabled;
      setState(() {
        isVideoOff = !videoTrack.enabled;
      });
      _showQuickFeedback(isVideoOff ? 'Camera off' : 'Camera on');
    }
  }

  Future<void> _switchCamera() async {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
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
      // Cancel all subscriptions
      _participantsSub?.cancel();
      for (final sub in _signalSubscriptions.values) {
        sub.cancel();
      }
      _signalSubscriptions.clear();

      _debugTimer?.cancel();
      _callTimer?.cancel();
      _pulseController.dispose();

      // Stop local stream
      _localStream?.getTracks().forEach((track) => track.stop());
      _localRenderer.srcObject = null;
      await _localRenderer.dispose();

      // Close all peer connections
      for (final pc in _peerConnections.values) {
        await pc.close();
      }
      _peerConnections.clear();

      // Dispose all remote renderers
      for (final renderer in _remoteRenderers.values) {
        renderer.srcObject?.getTracks().forEach((track) => track.stop());
        await renderer.dispose();
      }
      _remoteRenderers.clear();

      _remoteCandidateBuffers.clear();

      // Remove from participants
      final roomRef = _getRoomRef();
      await roomRef.collection('participants').doc(widget.userId).delete();

      setState(() {
        isConnecting = false;
        connectionStatus = 'Call ended';
      });
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }

  @override
  void dispose() {
    print('Disposing GroupChatRoom...');
    _cleanup();
    super.dispose();
  }

  Widget _buildStatusBar() {
    Color statusColor = isConnecting
        ? Colors.orange
        : _peerConnections.isNotEmpty
        ? Colors.green
        : Colors.red;
    IconData statusIcon = isConnecting
        ? Icons.sync
        : _peerConnections.isNotEmpty
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
              animation: _pulseAnimation,
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
                  if (_peerConnections.isNotEmpty && callDuration != '00:00')
                    Text(
                      callDuration,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Room ID: ${widget.roomId} copied')),
              ),
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
    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue, width: 2),
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
    );
  }

  Widget _buildRemoteVideoView(String userId, RTCVideoRenderer renderer) {
    final hasStream = renderer.srcObject != null;
    final hasVideoTrack = hasStream && renderer.srcObject!.getVideoTracks().isNotEmpty;

    return Container(
      width: MediaQuery.of(context).size.width / 2 - 16,
      height: 200,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: hasVideoTrack ? Colors.green.withOpacity(0.5) : Colors.white.withOpacity(0.3)
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
        child: hasVideoTrack
            ? RTCVideoView(
          renderer,
          key: ValueKey('remote_$userId'),
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          filterQuality: FilterQuality.medium,
        )
            : Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasStream ? Icons.videocam_off : Icons.person,
                  color: Colors.white54,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  hasStream ? 'Video Off' : 'Connecting...',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                Text(
                  userId.length > 10 ? '${userId.substring(0, 10)}...' : userId,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
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
              iconColor: Colors.white,
            ),
            _buildControlButton(
              icon: isVideoOff ? Icons.videocam_off : Icons.videocam,
              onPressed: _toggleVideo,
              backgroundColor: isVideoOff ? Colors.red : Colors.white.withOpacity(0.2),
              iconColor: Colors.white,
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
      body: Container(
        height: MediaQuery.of(context).size.height,
        child: Stack(
          children: [
            Positioned.fill(
              top: 80,
              bottom: 120,
              child: _remoteRenderers.isEmpty
                  ? Center(
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
                      isConnecting ? 'Connecting...' : 'Waiting for participants',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
                  : GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _remoteRenderers.length,
                itemBuilder: (context, index) {
                  final userId = _remoteRenderers.keys.elementAt(index);
                  return _buildRemoteVideoView(userId, _remoteRenderers[userId]!);
                },
              ),
            ),
            _buildStatusBar(),
            if (_localRenderer.srcObject != null)
              Positioned(
                top: 100,
                right: 16,
                child: _buildLocalVideoView(),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildControlButtons(),
            ),
          ],
        ),
      ),
    );
  }
}