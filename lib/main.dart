import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'chroma_key_preview.dart';
import 'background_layer.dart';

Future<void> main() async { WidgetsFlutterBinding.ensureInitialized(); runApp(const GreenScreenShotApp()); }

class GreenScreenShotApp extends StatelessWidget {
  const GreenScreenShotApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'Green Screen Shot',
    theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF07110A),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF20E070), brightness: Brightness.dark), useMaterial3: true),
    home: const CameraStudioPage());
}

class CameraStudioPage extends StatefulWidget { const CameraStudioPage({super.key}); @override State<CameraStudioPage> createState()=>_CameraStudioPageState(); }

class _CameraStudioPageState extends State<CameraStudioPage> with WidgetsBindingObserver {
  CameraController? _controller; List<CameraDescription> _cameras=[]; int _cameraIndex=0;
  bool _initializing=true,_recording=false,_saving=false,_showGuide=true,_chromaKey=true; FlashMode _flash=FlashMode.off;
  BackgroundSource _background = const BackgroundSource.none();
  Timer? _recordTimer; int _seconds=0; String? _error;

  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_start();}
  Future<void> _start() async {
    try {
      final cam=await Permission.camera.request(), mic=await Permission.microphone.request();
      if(!cam.isGranted||!mic.isGranted){setState(() {_initializing=false,_error='Camera and microphone permissions are required.'});return;}
      _cameras=await availableCameras(); if(_cameras.isEmpty) throw StateError('No camera found on this device.');
      await _openCamera(_cameraIndex);
    } catch(e){if(mounted)setState(() {_initializing=false,_error=e.toString()});}
  }
  Future<void> _openCamera(int index) async {
    final old=_controller;_controller=null;await old?.dispose();
    final c=CameraController(_cameras[index],ResolutionPreset.high,enableAudio:true,imageFormatGroup:ImageFormatGroup.yuv420);
    try{await c.initialize();await c.setFlashMode(_flash);if(!mounted){await c.dispose();return;}
      setState(() {_controller=c,_cameraIndex=index,_initializing=false,_error=null});}
    catch(e){await c.dispose();if(mounted)setState(() {_initializing=false,_error=e.toString()});}
  }
  Future<void> _switchCamera() async {if(_cameras.length<2||_recording)return;setState(()=>_initializing=true);await _openCamera((_cameraIndex+1)%_cameras.length);}
  Future<void> _pickImage() async {
    final x=await ImagePicker().pickImage(source: ImageSource.gallery);
    if(x!=null&&mounted)setState(()=>_background=BackgroundSource.image(x.path));
  }
  Future<void> _pickVideo() async {
    final x=await ImagePicker().pickVideo(source: ImageSource.gallery);
    if(x!=null&&mounted)setState(()=>_background=BackgroundSource.video(x.path));
  }
  Future<void> _toggleFlash() async {
    final c=_controller;if(c==null||!c.value.isInitialized)return;
    final next=switch(_flash){FlashMode.off=>FlashMode.auto,FlashMode.auto=>FlashMode.always,_=>FlashMode.off};
    try{await c.setFlashMode(next);setState(()=>_flash=next);}catch(_){}
  }
  Future<void> _toggleRecording() async {
    final c=_controller;if(c==null||!c.value.isInitialized||_saving)return;
    if(c.value.isRecordingVideo){await _stopRecording();return;}
    try{await c.startVideoRecording();setState(() {_recording=true,_seconds=0});
      _recordTimer?.cancel();_recordTimer=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState(()=>_seconds++);});}
    catch(e){if(mounted)_message('Could not start recording: $e');}
  }
  Future<void> _stopRecording() async {
    final c=_controller;if(c==null||!c.value.isRecordingVideo)return;_recordTimer?.cancel();setState(()=>_saving=true);
    try{
      final file=await c.stopVideoRecording();final dir=await getApplicationDocumentsDirectory();
      final path='${dir.path}/green_screen_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final saved=await file.saveTo(path);await GallerySaver.saveVideo(saved,albumName:'Green Screen Shot');
      if(mounted){setState(() {_recording=false,_saving=false});_message('Video saved to your gallery.');}
    }catch(e){if(mounted){setState(() {_recording=false,_saving=false});_message('Could not save video: $e');}}
  }
  void _message(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  String get _time{final m=(_seconds~/60).toString().padLeft(2,'0');final s=(_seconds%60).toString().padLeft(2,'0');return '$m:$s';}
  @override void didChangeAppLifecycleState(AppLifecycleState state){final c=_controller;if(c==null||!c.value.isInitialized)return;if(state==AppLifecycleState.inactive)c.dispose();else if(state==AppLifecycleState.resumed&&!_recording)_openCamera(_cameraIndex);}
  @override void dispose(){_recordTimer?.cancel();WidgetsBinding.instance.removeObserver(this);_controller?.dispose();super.dispose();}
  @override Widget build(BuildContext context){final c=_controller;return Scaffold(body:SafeArea(child:Stack(fit:StackFit.expand,children:[
    if(c!=null&&c.value.isInitialized)
      (_chromaKey
        ? ChromaKeyPreview(controller:c,background:BackgroundLayer(source:_background))
        : _CameraPreview(c))
    else _fallback(),
    if(_showGuide&&c!=null&&c.value.isInitialized)const IgnorePointer(child:_GreenScreenGuide()),_topBar(),_bottomControls(),if(_saving)_savingOverlay()
  ])));}
  Widget _fallback()=>Container(color:const Color(0xFF07110A),alignment:Alignment.center,padding:const EdgeInsets.all(28),child:_initializing?const CircularProgressIndicator():Column(mainAxisSize:MainAxisSize.min,children:[
    const Icon(Icons.videocam_off_rounded,size:64),const SizedBox(height:18),Text(_error??'Camera unavailable',textAlign:TextAlign.center),const SizedBox(height:18),
    FilledButton.icon(onPressed:_start,icon:const Icon(Icons.refresh),label:const Text('Try again'))]));
  Widget _topBar()=>Positioned(left:16,right:16,top:14,child:Row(children:[
    const Expanded(child:Text('GREEN SCREEN SHOT',style:TextStyle(fontWeight:FontWeight.w800,letterSpacing:1.2))),
    if(_recording)Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:Colors.black.withValues(alpha:.72),borderRadius:BorderRadius.circular(20)),child:Row(children:[
      Container(width:9,height:9,decoration:const BoxDecoration(color:Colors.red,shape:BoxShape.circle)),const SizedBox(width:7),Text(_time)])),
    const SizedBox(width:8),
      PopupMenuButton<String>(
        icon:const Icon(Icons.layers_rounded),
        onSelected:(v){if(v=='image')_pickImage();if(v=='video')_pickVideo();if(v=='none')setState(()=>_background=const BackgroundSource.none());if(v=='key')setState(()=>_chromaKey=!_chromaKey);},
        itemBuilder:(_)=>[
          PopupMenuItem(value:'key',child:Text(_chromaKey?'Disable Chroma Key':'Enable Chroma Key')),
          const PopupMenuItem(value:'image',child:Text('Background image')),
          const PopupMenuItem(value:'video',child:Text('Background video')),
          const PopupMenuItem(value:'none',child:Text('No background')),
        ],
      ),
      _RoundButton(icon:_showGuide?Icons.crop_free:Icons.crop_square,onTap:()=>setState(()=>_showGuide=!_showGuide))]));
  Widget _bottomControls(){final c=_controller;final has=c!=null&&c.value.isInitialized;return Positioned(left:18,right:18,bottom:18,child:Column(children:[
    if(!_recording)Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.symmetric(horizontal:14,vertical:9),
      decoration:BoxDecoration(color:Colors.black.withValues(alpha:.65),borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFF20E070).withValues(alpha:.5))),
      child:const Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.check_circle,color:Color(0xFF20E070),size:18),SizedBox(width:8),Text('Use an evenly lit green background')])),
    Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
      _RoundButton(icon:switch(_flash){FlashMode.off=>Icons.flash_off,FlashMode.auto=>Icons.flash_auto,_=>Icons.flash_on},onTap:has&&!_recording?_toggleFlash:null),
      GestureDetector(onTap:has?_toggleRecording:null,child:AnimatedContainer(duration:const Duration(milliseconds:180),width:78,height:78,padding:const EdgeInsets.all(6),
        decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:_recording?Colors.red:Colors.white,width:4)),
        child:AnimatedContainer(duration:const Duration(milliseconds:180),decoration:BoxDecoration(color:_recording?Colors.red:Colors.white,shape:_recording?BoxShape.rectangle:BoxShape.circle,borderRadius:_recording?BorderRadius.circular(13):null)))),
      _RoundButton(icon:Icons.flip_camera_ios_rounded,onTap:has&&!_recording?_switchCamera:null)])]));}
  Widget _savingOverlay()=>Container(color:Colors.black.withValues(alpha:.62),alignment:Alignment.center,child:const Column(mainAxisSize:MainAxisSize.min,children:[CircularProgressIndicator(),SizedBox(height:14),Text('Saving video…')]));
}

class _CameraPreview extends StatelessWidget {final CameraController controller;const _CameraPreview(this.controller);
 @override Widget build(BuildContext context){final size=controller.value.previewSize;final pa=size==null?1.0:size.height/size.width;final sa=MediaQuery.sizeOf(context).aspectRatio;var scale=sa/pa;if(scale<1)scale=1/scale;return ClipRect(child:Transform.scale(scale:scale,child:Center(child:CameraPreview(controller))));}}
class _GreenScreenGuide extends StatelessWidget {const _GreenScreenGuide();@override Widget build(BuildContext context)=>Center(child:FractionallySizedBox(widthFactor:.78,heightFactor:.68,child:Container(
 decoration:BoxDecoration(border:Border.all(color:const Color(0xFF20E070).withValues(alpha:.9),width:2),borderRadius:BorderRadius.circular(28)),
 child:const Stack(children:[Positioned(top:12,left:12,child:_Corner(top:true,left:true)),Positioned(top:12,right:12,child:_Corner(top:true,left:false)),Positioned(bottom:12,left:12,child:_Corner(top:false,left:true)),Positioned(bottom:12,right:12,child:_Corner(top:false,left:false))]))));}}
class _Corner extends StatelessWidget {final bool top,left;const _Corner({required this.top,required this.left});@override Widget build(BuildContext context)=>Container(width:22,height:22,decoration:BoxDecoration(border:Border(
 top:top?const BorderSide(color:Color(0xFF20E070),width:3):BorderSide.none,bottom:!top?const BorderSide(color:Color(0xFF20E070),width:3):BorderSide.none,
 left:left?const BorderSide(color:Color(0xFF20E070),width:3):BorderSide.none,right:!left?const BorderSide(color:Color(0xFF20E070),width:3):BorderSide.none)));}}
class _RoundButton extends StatelessWidget {final IconData icon;final VoidCallback? onTap;const _RoundButton({required this.icon,required this.onTap});
 @override Widget build(BuildContext context)=>Material(color:Colors.black.withValues(alpha:.58),shape:const CircleBorder(),child:InkWell(onTap:onTap,customBorder:const CircleBorder(),child:Padding(padding:const EdgeInsets.all(14),child:Icon(icon,size:24,color:onTap==null?Colors.white38:Colors.white))));}
