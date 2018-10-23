import 'dart:math';

import 'package:flutter/material.dart';
import 'package:music_player/bottom_controls.dart';
import 'package:music_player/radial_drag_gesture_detector.dart';
import 'package:music_player/songs.dart';
import 'package:music_player/theme.dart';
import 'package:fluttery_audio/fluttery_audio.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Music Player',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: new MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  double _seekPercent;

  @override
  Widget build(BuildContext context) {
    return AudioPlaylist(
      playlist: demoPlaylist.songs.map((DemoSong s)=>s.audioUrl).toList(growable: false),
      playbackState: PlaybackState.paused,
      child: new Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0.0,
          leading: new IconButton(
            icon: Icon(Icons.arrow_back_ios),
            color: const Color(0xFFDDDDDD),
            onPressed: (){},
          ),
          actions: <Widget>[
            new IconButton(
              icon: Icon(Icons.menu),
              color: const Color(0xFFDDDDDD),
              onPressed: (){},
            ),
          ],
          title: Text(''),
        ),
        body: new Column(
          children: <Widget>[
            //seek bar
            new Expanded(
              child: AudioPlaylistComponent(
                playlistBuilder: (BuildContext context, Playlist playlist, Widget child){

                  String albumArtUrl = demoPlaylist.songs[playlist.activeIndex].albumArtUrl;

                  return AudioRadialSeekBar(
                    albumArtUrl: albumArtUrl,
                  );
                },
              )
            ),
            //visualizer
            new Container(
              width: double.infinity,
              height: 125.0,
              child: new Visualizer(
                builder: (BuildContext context, List<int> fft){


                  return CustomPaint(
                    painter: VisualizerPainter(
                        fft,
                        lightAccentColor,
                        125.0
                    )
//                    child: Container(),
                  );
                },
              ),
            ),

            //controls
            new BottomControls()
          ],
        )
      ),
    );
  }
}

class VisualizerPainter extends CustomPainter{

  final List<int> fft;
  final Color color;
  final double height;
  final Paint wavePaint;

  VisualizerPainter(
      this.fft,
      this.color,
      this.height,
      ) : this.wavePaint = new Paint()
          ..color = color.withOpacity(0.75)
          ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    _renderWaves(canvas,size);
  }

  void _renderWaves(Canvas canvas, Size size){
    final histogramLow = _createHistogram(fft, 15,2,((fft.length) / 4).floor());
    final histogramHigh = _createHistogram(fft, 15, ((fft.length) / 4).ceil(),((fft.length)/2).floor());

    _renderHistogram(canvas,size,histogramLow);
    _renderHistogram(canvas,size,histogramHigh);
  }

  void _renderHistogram(Canvas canvas, Size size, List<int> histogram) {
    if(histogram.length==0)return;

    final pointsToGraph = histogram.length;
    final widthPerSample = (size.width / (pointsToGraph - 2)).floor();

    final points = new List<double>.filled(pointsToGraph*4, 0.0);

    for(int i = 0; i < histogram.length-1;i++){
      points[i*4] = (i*widthPerSample).toDouble();
      points[i*4 +1] = size.height - histogram[i].toDouble();

      points[i*4 + 2] = ((i+1) * widthPerSample).toDouble();
      points[i*4 +3] = size.height - histogram[i+1].toDouble();
    }

    Path path = new Path();
    path.moveTo(0.0, size.height);
    path.lineTo(points[0], points[1]);
    for(int i = 2; i <points.length - 4; i+=2){
      path.cubicTo(
        points[i-2] +10.0, points[i-1],
        points[i] - 10.0, points[i+1],
        points[i],points[i+1]
      );
    }

    path.lineTo(size.width,size.height);
    path.close();

    canvas.drawPath(path, wavePaint);

  }


  List<int> _createHistogram(List<int> samples, int bucketCount, [int start, int end]){
    if(start==end)
      return const [];

    start = start ?? 0;
    end = end ?? samples.length-1;
    final int sampleCount = end-start+1;

    final int samplesPerBucket = (sampleCount / bucketCount).floor();

    if(samplesPerBucket==0) return const [];

    final int actualSampleCount = sampleCount - (sampleCount %samplesPerBucket);

    List<int> histogram = new List<int>.filled(bucketCount, 0);

    //add up freq amount for each bucket
    for(int i = start; i<=start+actualSampleCount;i++){

      //ignore imaginary part of fft's
      if((i-start)%2==1){
        continue;
      }

      int bucketIndex = ((i-start)/samplesPerBucket).floor();

      histogram[bucketIndex]+=samples[i];

    }

    //massage data for visualization

    for(var i = 0; i < histogram.length;i++){
      histogram[i] = (histogram[i]/samplesPerBucket).abs().round();
    }

    return histogram;

  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }

}

class AudioRadialSeekBar extends StatefulWidget {

  final String albumArtUrl;

  const AudioRadialSeekBar({Key key, this.albumArtUrl}) : super(key: key);

  @override
  _AudioRadialSeekBarState createState() => _AudioRadialSeekBarState();
}

class _AudioRadialSeekBarState extends State<AudioRadialSeekBar> {

  double _seekPercent;

  @override
  Widget build(BuildContext context) {
    return AudioComponent(
        updateMe: [
          WatchableAudioProperties.audioPlayhead,
          WatchableAudioProperties.audioSeeking,
        ],
        playerBuilder: (BuildContext context, AudioPlayer player, Widget child){

          double playbackProgress = 0.0;
          if(player.audioLength != null && player.position != null){
            playbackProgress = player.position.inMilliseconds / player.audioLength.inMilliseconds;
          }

          _seekPercent = player.isSeeking? _seekPercent : null;

          return RadialSeekBar(
            progress: playbackProgress,
            seekPercent: _seekPercent,
            onSeekRequested: (double seekPercent){
              setState(() => _seekPercent = seekPercent);

              final seekMillis = (player.audioLength.inMilliseconds * seekPercent).round();
              player.seek(new Duration(milliseconds: seekMillis));
            },
            child: Container(
              color: accentColor,
              child: Image.network(
                widget.albumArtUrl,
                fit: BoxFit.cover,
              ),
            )
          );
        }
    );
  }
}


class RadialSeekBar extends StatefulWidget {

  final double seekPercent;
  final double progress;
  final Function(double) onSeekRequested;
  final Widget child;

  const RadialSeekBar({Key key,
    this.seekPercent=0.0,
    this.progress=0.0,
    this.onSeekRequested,
    this.child
  }) : super(key: key);

  @override
  _RadialSeekBarState createState() => _RadialSeekBarState();
}

class _RadialSeekBarState extends State<RadialSeekBar> {


  PolarCoord _startDragCoord;
  double _progress = 0.0;
  double _startDragPercent;
  double _currentDragPercent;

  @override
  void initState() {
    super.initState();
    _progress = widget.progress;
  }

  @override
  void didUpdateWidget(RadialSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _progress = widget.progress;
  }

  void _OnDragStart(PolarCoord start){
    _startDragCoord = start;
    _startDragPercent = _progress;
  }

  void _OnDragUpdate(PolarCoord update){
    final dragAngle = update.angle - _startDragCoord.angle;
    final dragPercent = dragAngle / (2*pi);

    setState(() => _currentDragPercent = (_startDragPercent+dragPercent) % 1.0);

  }

  void _OnDragEnd(){

    if(widget.onSeekRequested != null){
      widget.onSeekRequested(_currentDragPercent);
    }

    setState(() {
      _currentDragPercent = null;
      _startDragPercent = 0.0;
      _startDragCoord = null;
    });
  }

  @override
  Widget build(BuildContext context) {

    double thumbPosition = _progress;
    if(_currentDragPercent != null){
      thumbPosition = _currentDragPercent;
    } else if(widget.seekPercent != null){
      thumbPosition = widget.seekPercent;
    }

    return RadialDragGestureDetector(
      onRadialDragStart: _OnDragStart,
      onRadialDragUpdate: _OnDragUpdate,
      onRadialDragEnd: _OnDragEnd,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,
        child: Center(
          child: new Container(
            width: 140.0,
            height: 140.0,
            child: RadialProgressBar(
              progressPercent: _progress,
              thumbPosition: thumbPosition,
              progressColor: accentColor,
              thumbColor: lightAccentColor,
              trackColor: const Color(0xFFDDDDDD),
              innerPadding: const EdgeInsets.all(10.0),
              child: ClipOval(
                clipper: CircleClipper(),
                child: widget.child
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class RadialProgressBar extends StatefulWidget {

  final Widget child;
  final double trackWidth;
  final Color trackColor;
  final double progressWidth;
  final Color progressColor;
  final double progressPercent;
  final double thumbSize;
  final Color thumbColor;
  final double thumbPosition;
  final EdgeInsets outerPadding;
  final EdgeInsets innerPadding;

  RadialProgressBar({
    this.child,
    this.trackWidth = 3.0,
    this.trackColor = Colors.grey,
    this.progressWidth = 5.0,
    this.progressPercent = 0.0,
    this.progressColor = Colors.black,
    this.thumbSize = 10.0,
    this.thumbColor = Colors.black,
    this.thumbPosition = 0.0,
    this.outerPadding = const EdgeInsets.all(0.0),
    this.innerPadding = const EdgeInsets.all(0.0),
});

  @override
  _RadialProgressBarState createState() => _RadialProgressBarState();
}

class _RadialProgressBarState extends State<RadialProgressBar> {

  EdgeInsets _insetsForPainter(){
    //make room for painted track, prg and thumb
    final outerThickness = max(widget.trackWidth, max(widget.progressWidth,widget.thumbSize)) / 2.0;//half overlap
    
    return new EdgeInsets.all(outerThickness);

  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.outerPadding,
      child: CustomPaint(
        foregroundPainter: RadialSeekBarPainter(
          trackWidth: widget.trackWidth,
          trackColor: widget.trackColor,
          progressColor: widget.progressColor,
          progressWidth: widget.progressWidth,
          progressPercent: widget.progressPercent,
          thumbColor: widget.thumbColor,
          thumbPosition: widget.thumbPosition,
          thumbSize: widget.thumbSize
        ),
        child: Padding(
          padding: _insetsForPainter() + widget.innerPadding,
          child: widget.child,
        ),
      ),
    );
  }
}

class RadialSeekBarPainter extends CustomPainter{

  final double trackWidth;
  final Paint trackPaint;
  final double progressWidth;
  final double progressPercent;
  final Paint progressPaint;
  final double thumbSize;
  final Paint thumbPaint;
  final double thumbPosition;


  RadialSeekBarPainter({
    @required this.trackWidth,
    @required trackColor,
    @required this.progressWidth,
    @required this.progressPercent,
    @required progressColor,
    @required this.thumbSize,
    @required thumbColor,
    @required this.thumbPosition,
  }) : trackPaint = new Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackWidth,
      progressPaint = new Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = progressWidth
      ..strokeCap = StrokeCap.round,
      thumbPaint = new Paint()
      ..color = thumbColor
      ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {

    //space between container and seekbar - largest thing
    final outerThickness = max(trackWidth, max(progressWidth,thumbSize));
    Size constrainedSize = new Size(
      size.width-outerThickness,
      size.height-outerThickness,
    );

    //Paint track
    final center = new Offset(size.width/2, size.height/2);
    final radius = min(constrainedSize.width,constrainedSize.height)/2;

    canvas.drawCircle(
        center,
        radius,
        trackPaint
    );

    //paint progress
    final progAngle = 2*pi * progressPercent;

    canvas.drawArc(
        new Rect.fromCircle(
          center: center,
          radius: radius,
        ),
        -pi/2,
        progAngle,
        false,
        progressPaint
    );

    //paint thumb
    final thumbAngle = 2*pi*thumbPosition - (pi/2);
    final thumbX = cos(thumbAngle) * radius;
    final thumbY = sin(thumbAngle) * radius;
    final thumbRadius = thumbSize/2;
    final thumbCenter = Offset(thumbX,thumbY) + center;

    canvas.drawCircle(
        thumbCenter,
        thumbRadius,
        thumbPaint
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }

}




class CircleClipper  extends CustomClipper<Rect>{
  @override
  Rect getClip(Size size) {
    return new Rect.fromCircle(
      center: new Offset(size.width/2, size.height/2),
      radius: min(size.width,size.height)/2,
    );
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) {
    return true;
  }

}
