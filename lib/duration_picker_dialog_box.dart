library duration_picker_dialog_box;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

enum _ScreenSize { mobile, desktop, tablet }

const _smallBreakPoint = 700.0;
const _mediumBreakPoint = 940.0;

_ScreenSize getScreenSize(double width) {
  if (width < _smallBreakPoint) {
    return _ScreenSize.mobile;
  } else if (width < _mediumBreakPoint) {
    return _ScreenSize.tablet;
  } else {
    return _ScreenSize.desktop;
  }
}

const Duration _kDialAnimateDuration = const Duration(milliseconds: 200);

const double _kDurationPickerWidthPortrait = 650.0;
const double _kDurationPickerWidthLandscape = 600.0;

//const double _kDurationPickerHeightPortrait = 380.0;
const double _kDurationPickerHeightPortrait = 360.0;
const double _kDurationPickerHeightLandscape = 310.0;

const double _kTwoPi = 2 * math.pi;

enum DurationPickerMode { Day, Hour, Minute, Second, MilliSecond, MicroSecond }

extension _DurationPickerModeExtenstion on DurationPickerMode {
  static const nextItems = {
    DurationPickerMode.Day: DurationPickerMode.Hour,
    DurationPickerMode.Hour: DurationPickerMode.Minute,
    DurationPickerMode.Minute: DurationPickerMode.Second,
    DurationPickerMode.Second: DurationPickerMode.MilliSecond,
    DurationPickerMode.MilliSecond: DurationPickerMode.MicroSecond,
    DurationPickerMode.MicroSecond: DurationPickerMode.Day,
  };
  static const prevItems = {
    DurationPickerMode.Day: DurationPickerMode.MicroSecond,
    DurationPickerMode.Hour: DurationPickerMode.Day,
    DurationPickerMode.Minute: DurationPickerMode.Hour,
    DurationPickerMode.Second: DurationPickerMode.Minute,
    DurationPickerMode.MilliSecond: DurationPickerMode.Second,
    DurationPickerMode.MicroSecond: DurationPickerMode.MilliSecond,
  };

  DurationPickerMode? get next => nextItems[this];

  DurationPickerMode? get prev => prevItems[this];
}

class _TappableLabel {
  _TappableLabel({
    required this.value,
    required this.painter,
    required this.onTap,
  });

  /// The value this label is displaying.
  final int value;

  /// Paints the text of the label.
  final TextPainter painter;

  /// Called when a tap gesture is detected on the label.
  final VoidCallback onTap;
}

class _DialPainterNew extends CustomPainter {
  _DialPainterNew({
    required this.primaryLabels,
    required this.secondaryLabels,
    required this.backgroundColor,
    required this.accentColor,
    required this.dotColor,
    required this.theta,
    required this.textDirection,
    required this.selectedValue,
  }) : super(repaint: PaintingBinding.instance.systemFonts);

  final List<_TappableLabel> primaryLabels;
  final List<_TappableLabel> secondaryLabels;
  final Color backgroundColor;
  final Color accentColor;
  final Color dotColor;
  final double theta;
  final TextDirection textDirection;
  final int selectedValue;

  static const double _labelPadding = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.shortestSide / 2.0;
    final Offset center = Offset(size.width / 2.0, size.height / 2.0);
    final Offset centerPoint = center;
    canvas.drawCircle(centerPoint, radius, Paint()..color = backgroundColor);

    final double labelRadius = radius - _labelPadding;
    Offset getOffsetForTheta(double theta) {
      return center +
          Offset(labelRadius * math.cos(theta), -labelRadius * math.sin(theta));
    }

    void paintLabels(List<_TappableLabel> labels) {
      final double labelThetaIncrement = -_kTwoPi / labels.length;
      double labelTheta = math.pi / 2.0;

      for (final _TappableLabel label in labels) {
        final TextPainter labelPainter = label.painter;
        final Offset labelOffset =
            Offset(-labelPainter.width / 2.0, -labelPainter.height / 2.0);
        labelPainter.paint(canvas, getOffsetForTheta(labelTheta) + labelOffset);
        labelTheta += labelThetaIncrement;
      }
    }

    paintLabels(primaryLabels);

    final Paint selectorPaint = Paint()..color = accentColor;
    final Offset focusedPoint = getOffsetForTheta(theta);
    const double focusedRadius = _labelPadding - 4.0;
    canvas.drawCircle(centerPoint, 4.0, selectorPaint);
    canvas.drawCircle(focusedPoint, focusedRadius, selectorPaint);
    selectorPaint.strokeWidth = 2.0;
    canvas.drawLine(centerPoint, focusedPoint, selectorPaint);

    // Add a dot inside the selector but only when it isn't over the labels.
    // This checks that the selector's theta is between two labels. A remainder
    // between 0.1 and 0.45 indicates that the selector is roughly not above any
    // labels. The values were derived by manually testing the dial.
    int len = primaryLabels.length;
    //len = 14;
    final double labelThetaIncrement = -_kTwoPi / len;
    bool flag = len == 10
        ? !(theta % labelThetaIncrement > 0.25 &&
            theta % labelThetaIncrement < 0.4)
        : (theta % labelThetaIncrement > 0.1 &&
            theta % labelThetaIncrement < 0.45);
    if (flag) {
      canvas.drawCircle(focusedPoint, 2.0, selectorPaint..color = dotColor);
    }

    final Rect focusedRect = Rect.fromCircle(
      center: focusedPoint,
      radius: focusedRadius,
    );
    canvas
      ..save()
      ..clipPath(Path()..addOval(focusedRect));
    paintLabels(secondaryLabels);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DialPainterNew oldPainter) {
    return oldPainter.primaryLabels != primaryLabels ||
        oldPainter.secondaryLabels != secondaryLabels ||
        oldPainter.backgroundColor != backgroundColor ||
        oldPainter.accentColor != accentColor ||
        oldPainter.theta != theta;
  }
}

class _Dial extends StatefulWidget {
  const _Dial({
    required this.value,
    required this.mode,
    required this.onChanged,
  });

  final int value;
  final DurationPickerMode mode;
  final ValueChanged<int> onChanged;

  @override
  _DialState createState() => _DialState();
}

class _DialState extends State<_Dial> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _thetaController = AnimationController(
      duration: _kDialAnimateDuration,
      vsync: this,
    );
    _thetaTween = Tween<double>(begin: _getThetaForTime(widget.value));
    _theta = _thetaController!
        .drive(CurveTween(curve: Easing.legacy))
        .drive(_thetaTween!)
      ..addListener(() => setState(() {
            /* _theta.value has changed */
          }));
  }

  ThemeData? themeData;
  MaterialLocalizations? localizations;
  MediaQueryData? media;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    assert(debugCheckHasMediaQuery(context));
    themeData = Theme.of(context);
    localizations = MaterialLocalizations.of(context);
    media = MediaQuery.of(context);
  }

  @override
  void didUpdateWidget(_Dial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode != oldWidget.mode || widget.value != oldWidget.value) {
      if (!_dragging) _animateTo(_getThetaForTime(widget.value));
    }
  }

  @override
  void dispose() {
    _thetaController!.dispose();
    super.dispose();
  }

  Tween<double>? _thetaTween;
  Animation<double>? _theta;
  AnimationController? _thetaController;
  bool _dragging = false;

  static double _nearest(double target, double a, double b) {
    return ((target - a).abs() < (target - b).abs()) ? a : b;
  }

  void _animateTo(double targetTheta) {
    final double? currentTheta = _theta!.value;
    double beginTheta =
        _nearest(targetTheta, currentTheta!, currentTheta + _kTwoPi);
    beginTheta = _nearest(targetTheta, beginTheta, currentTheta - _kTwoPi);
    _thetaTween!
      ..begin = beginTheta
      ..end = targetTheta;
    _thetaController!
      ..value = 0.0
      ..forward();
  }

  double _getThetaForTime(int value) {
    double fraction;
    switch (widget.mode) {
      case DurationPickerMode.Hour:
        fraction = (value / Duration.hoursPerDay) % Duration.hoursPerDay;
        break;
      case DurationPickerMode.Minute:
        fraction = (value / Duration.minutesPerHour) % Duration.minutesPerHour;
        break;
      case DurationPickerMode.Second:
        fraction =
            (value / Duration.secondsPerMinute) % Duration.secondsPerMinute;
        break;
      case DurationPickerMode.MilliSecond:
        fraction = (value / Duration.millisecondsPerSecond) %
            Duration.millisecondsPerSecond;
        break;
      case DurationPickerMode.MicroSecond:
        fraction = (value / Duration.microsecondsPerMillisecond) %
            Duration.microsecondsPerMillisecond;

        break;
      default:
        fraction = -1;
        break;
    }
    return (math.pi / 2.0 - fraction * _kTwoPi) % _kTwoPi;
  }

  int _getTimeForTheta(double theta) {
    final double fraction = (0.25 - (theta % _kTwoPi) / _kTwoPi) % 1.0;
    int result;
    switch (widget.mode) {
      case DurationPickerMode.Hour:
        result =
            (fraction * Duration.hoursPerDay).round() % Duration.hoursPerDay;
        break;
      case DurationPickerMode.Minute:
        result = (fraction * Duration.minutesPerHour).round() %
            Duration.minutesPerHour;
        break;
      case DurationPickerMode.Second:
        result = (fraction * Duration.secondsPerMinute).round() %
            Duration.secondsPerMinute;
        break;
      case DurationPickerMode.MilliSecond:
        result = (fraction * Duration.millisecondsPerSecond).round() %
            Duration.millisecondsPerSecond;
        break;
      case DurationPickerMode.MicroSecond:
        result = (fraction * Duration.microsecondsPerMillisecond).round() %
            Duration.microsecondsPerMillisecond;
        break;
      default:
        result = -1;
        break;
    }
    return result;
  }

  int _notifyOnChangedIfNeeded() {
    final int current = _getTimeForTheta(_theta!.value);
    if (current != widget.value) widget.onChanged(current);
    return current;
  }

  void _updateThetaForPan({bool roundMinutes = false}) {
    setState(() {
      final Offset offset = _position! - _center!;
      double angle =
          (math.atan2(offset.dx, offset.dy) - math.pi / 2.0) % _kTwoPi;
      if (roundMinutes) {
        angle = _getThetaForTime(_getTimeForTheta(angle));
      }
      _thetaTween!
        ..begin = angle
        ..end = angle;
    });
  }

  Offset? _position;
  Offset? _center;

  void _handlePanStart(DragStartDetails details) {
    assert(!_dragging);
    _dragging = true;
    final RenderBox box = context.findRenderObject() as RenderBox;
    _position = box.globalToLocal(details.globalPosition);
    _center = box.size.center(Offset.zero);
    _updateThetaForPan();
    _notifyOnChangedIfNeeded();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    _position = _position! + details.delta;
    _updateThetaForPan();
    _notifyOnChangedIfNeeded();
  }

  void _handlePanEnd(DragEndDetails details) {
    assert(_dragging);
    _dragging = false;
    _position = null;
    _center = null;
    _animateTo(_getThetaForTime(widget.value));
  }

  void _handleTapUp(TapUpDetails details) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    _position = box.globalToLocal(details.globalPosition);
    _center = box.size.center(Offset.zero);
    _updateThetaForPan(roundMinutes: true);
    final int newValue = _notifyOnChangedIfNeeded();

    _announceToAccessibility(context, localizations!.formatDecimal(newValue));
    _animateTo(_getThetaForTime(_getTimeForTheta(_theta!.value)));
    _dragging = false;

    _position = null;
    _center = null;
  }

  void _selectValue(int value) {
    _announceToAccessibility(context, localizations!.formatDecimal(value));
    final double angle = _getThetaForTime(widget.value);
    _thetaTween!
      ..begin = angle
      ..end = angle;
    _notifyOnChangedIfNeeded();
  }

  static const List<int> _twentyFourHours = <int>[
    0,
    2,
    4,
    6,
    8,
    10,
    12,
    14,
    16,
    18,
    20,
    22
  ];

  _TappableLabel _buildTappableLabel(TextTheme textTheme, Color color,
      int value, String label, VoidCallback onTap) {
    final TextStyle style = textTheme.bodyLarge!.copyWith(color: color);
    final double labelScaleFactor =
        math.min(MediaQuery.of(context).textScaleFactor, 2.0);
    return _TappableLabel(
      value: value,
      painter: TextPainter(
        text: TextSpan(style: style, text: label),
        textDirection: TextDirection.ltr,
        textScaleFactor: labelScaleFactor,
      )..layout(),
      onTap: onTap,
    );
  }

  List<_TappableLabel> _build24HourRing(TextTheme textTheme, Color color) =>
      <_TappableLabel>[
        for (final int hour in _twentyFourHours)
          _buildTappableLabel(
            textTheme,
            color,
            hour,
            hour.toString(),
            () {
              _selectValue(hour);
            },
          ),
      ];

  List<_TappableLabel> _buildMinutes(TextTheme textTheme, Color color) {
    const List<int> _minuteMarkerValues = <int>[
      0,
      5,
      10,
      15,
      20,
      25,
      30,
      35,
      40,
      45,
      50,
      55
    ];

    return <_TappableLabel>[
      for (final int minute in _minuteMarkerValues)
        _buildTappableLabel(
          textTheme,
          color,
          minute,
          minute.toString(),
          () {
            _selectValue(minute);
          },
        ),
    ];
  }

  List<_TappableLabel> _buildMSeconds(TextTheme textTheme, Color color) {
    const List<int> _minuteMarkerValues = <int>[
      0,
      100,
      200,
      300,
      400,
      500,
      600,
      700,
      800,
      900
    ];

    return <_TappableLabel>[
      for (final int minute in _minuteMarkerValues)
        _buildTappableLabel(
          textTheme,
          color,
          minute,
          minute.toString(),
          () {
            _selectValue(minute);
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TimePickerThemeData pickerTheme = TimePickerTheme.of(context);
    final Color backgroundColor = pickerTheme.dialBackgroundColor ??
        themeData!.colorScheme.onSurface.withOpacity(0.12);
    final Color accentColor =
        pickerTheme.dialHandColor ?? themeData!.colorScheme.primary;
    final Color primaryLabelColor = WidgetStateProperty.resolveAs(
            pickerTheme.dialTextColor, <WidgetState>{}) ??
        themeData!.colorScheme.onSurface;
    final Color secondaryLabelColor = WidgetStateProperty.resolveAs(
            pickerTheme.dialTextColor, <WidgetState>{WidgetState.selected}) ??
        themeData!.colorScheme.onPrimary;
    List<_TappableLabel> primaryLabels;
    List<_TappableLabel> secondaryLabels;
    int selectedDialValue;
    switch (widget.mode) {
      case DurationPickerMode.Hour:
        selectedDialValue = widget.value;
        primaryLabels = _build24HourRing(theme.textTheme, primaryLabelColor);
        secondaryLabels =
            _build24HourRing(theme.textTheme, secondaryLabelColor);
        break;
      case DurationPickerMode.Minute:
        selectedDialValue = widget.value;
        primaryLabels = _buildMinutes(theme.textTheme, primaryLabelColor);
        secondaryLabels = _buildMinutes(theme.textTheme, secondaryLabelColor);
        break;
      case DurationPickerMode.Second:
        selectedDialValue = widget.value;
        primaryLabels = _buildMinutes(theme.textTheme, primaryLabelColor);
        secondaryLabels = _buildMinutes(theme.textTheme, secondaryLabelColor);
        break;
      case DurationPickerMode.MilliSecond:
        selectedDialValue = widget.value;
        primaryLabels = _buildMSeconds(theme.textTheme, primaryLabelColor);
        secondaryLabels = _buildMSeconds(theme.textTheme, secondaryLabelColor);
        break;
      case DurationPickerMode.MicroSecond:
        selectedDialValue = widget.value;
        primaryLabels = _buildMSeconds(theme.textTheme, primaryLabelColor);
        secondaryLabels = _buildMSeconds(theme.textTheme, secondaryLabelColor);
        break;
      default:
        selectedDialValue = -1;
        primaryLabels = <_TappableLabel>[];
        secondaryLabels = <_TappableLabel>[];
    }

    return GestureDetector(
      excludeFromSemantics: true,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onTapUp: _handleTapUp,
      child: CustomPaint(
        key: const ValueKey<String>('duration-picker-dial'),
        painter: _DialPainterNew(
          selectedValue: selectedDialValue,
          primaryLabels: primaryLabels,
          secondaryLabels: secondaryLabels,
          backgroundColor: backgroundColor,
          accentColor: accentColor,
          dotColor: theme.colorScheme.surface,
          theta: _theta!.value,
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }
}

/// A duration picker designed to appear inside a popup dialog.
///
/// Pass this widget to [showDialog]. The value returned by [showDialog] is the
/// selected [Duration] if the user taps the "OK" button, or null if the user
/// taps the "CANCEL" button. The selected time is reported by calling
/// [Navigator.pop].
class _DurationPickerDialog extends StatefulWidget {
  /// Creates a duration picker.
  ///
  /// [initialTime] must not be null.
  const _DurationPickerDialog(
      {Key? key,
      required this.initialDuration,
      this.cancelText,
      this.confirmText,
      this.showHead = true,
      this.durationPickerMode})
      : super(key: key);

  /// The duration initially selected when the dialog is shown.
  final Duration initialDuration;

  /// Optionally provide your own text for the cancel button.
  ///
  /// If null, the button uses [MaterialLocalizations.cancelButtonLabel].
  final String? cancelText;

  /// Optionally provide your own text for the confirm button.
  ///
  /// If null, the button uses [MaterialLocalizations.okButtonLabel].
  final String? confirmText;

  final bool showHead;

  final DurationPickerMode? durationPickerMode;

  @override
  _DurationPickerState createState() => new _DurationPickerState();
}

class _DurationPickerState extends State<_DurationPickerDialog> {
  Duration? get selectedDuration => _selectedDuration;
  Duration? _selectedDuration;

  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.initialDuration;
  }

  void _handleDurationChanged(Duration value) {
    setState(() {
      _selectedDuration = value;
    });
  }

  void _handleCancel() {
    Navigator.pop(context);
  }

  void _handleOk() {
    Navigator.pop(context, _selectedDuration ?? Duration());
  }

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations localizations =
        MaterialLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    /// Duration Head with heading as Duration.
    final Widget head = Padding(
      padding: EdgeInsets.only(top: 8),
      child: Text(
        "Duration".toUpperCase(),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
    );

    /// Duration Picker Widget.
    final Widget picker = new Padding(
        padding:
            const EdgeInsets.only(left: 16.0, right: 16, top: 8, bottom: 8),
        child: DurationPicker(
          duration: _selectedDuration ?? Duration(),
          onChange: _handleDurationChanged,
        ));

    /// Action Buttons - Cancel and OK
    final Widget actions = Container(
      alignment: AlignmentDirectional.centerEnd,
      constraints: const BoxConstraints(minHeight: 42.0),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: OverflowBar(
        spacing: 2,
        overflowAlignment: OverflowBarAlignment.end,
        children: <Widget>[
          TextButton(
            onPressed: _handleCancel,
            child: Text(widget.cancelText ?? localizations.cancelButtonLabel),
          ),
          TextButton(
            onPressed: _handleOk,
            child: Text(widget.confirmText ?? localizations.okButtonLabel),
          ),
        ],
      ),
    );

    /// Widget with Head as Duration, Duration Picker Widget and Dialog as Actions - Cancel and OK.
    final Widget pickerAndActions = new Container(
      color: theme.dialogBackgroundColor,
      child: new Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          widget.showHead ? head : Container(),
          new Expanded(child: picker),
          // picker grows and shrinks with the available space
          actions,
        ],
      ),
    );

    final Dialog dialog = new Dialog(child: new OrientationBuilder(
        builder: (BuildContext context, Orientation orientation) {
      switch (orientation) {
        case Orientation.portrait:
          return new SizedBox(
              width: _kDurationPickerWidthPortrait,
              height: _kDurationPickerHeightPortrait,
              child: new Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    new Expanded(
                      child: pickerAndActions,
                    ),
                  ]));
        case Orientation.landscape:
          return new SizedBox(
              width: widget.showHead
                  ? _kDurationPickerWidthLandscape
                  : _kDurationPickerWidthLandscape,
              height: widget.showHead
                  ? _kDurationPickerHeightLandscape + 28
                  : _kDurationPickerHeightLandscape,
              child: new Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    new Flexible(
                      child: pickerAndActions,
                    ),
                  ]));
      }
    }));

    return new Theme(
      data: theme.copyWith(
        dialogBackgroundColor: Colors.transparent,
      ),
      child: dialog,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

void _announceToAccessibility(BuildContext context, String message) {
  SemanticsService.announce(message, Directionality.of(context));
}

/// Shows a dialog containing the duration picker.
///
/// The returned Future resolves to the duration selected by the user when the user
/// closes the dialog. If the user cancels the dialog, null is returned.
///
/// To show a dialog with [initialDuration] equal to the Duration with 0 milliseconds:
/// To show a dialog with [DurationPickerMode] equal to the Duration Mode like hour, second,etc.:
/// To show a dialog with [showHead] equal to boolean (Default is true) to show Head as Duration:
///
/// Optionally provide your own text for the confirm button [confirmText.
/// If null, the button uses [MaterialLocalizations.okButtonLabel].
///
/// Optionally provide your own text for the cancel button [cancelText].
/// If null, the button uses [MaterialLocalizations.cancelButtonLabel].
///
/// ```dart
/// showDurationPicker(
///   initialDuration: initialDuration,
///   durationPickerMode: durationPickerMode,
///   showHead: showHead,
///   confirmText: confirmText,
///   cancelText: cancelText,
///    );
/// ```
Future<Duration?> showDurationPicker(
    {required BuildContext context,
    required Duration initialDuration,
    DurationPickerMode? durationPickerMode,
    bool showHead = true,
    String? confirmText,
    String? cancelText}) async {
  return await showDialog<Duration>(
    context: context,
    builder: (BuildContext context) => new _DurationPickerDialog(
      initialDuration: initialDuration,
      durationPickerMode: durationPickerMode,
      showHead: showHead,
      confirmText: confirmText,
      cancelText: cancelText,
    ),
  );
}

/// A Widget for duration picker.
///
/// [duration] - a initial Duration for Duration Picker when not provided initialize with Duration().
/// [onChange] - a function to be called when duration changed and cannot be null.
/// [durationPickerMode] - Duration Picker Mode to show Widget with Days,  Hours, Minutes, Seconds, Milliseconds, Microseconds, By default Duration Picker Mode is Minute.
/// [width] -  Width of Duration Picker Widget and can be null.
/// [height] -  Height of Duration Picker Widget and can be null.
///
/// ```dart
/// DurationPicker(
///   duration: Duration(),
///   onChange: onChange,
///   height: 600,
///   width: 700
/// );
/// ```
class DurationPicker extends StatefulWidget {
  final Duration duration;
  final ValueChanged<Duration> onChange;
  final DurationPickerMode? durationPickerMode;

  final double? width;
  final double? height;

  DurationPicker(
      {this.duration = const Duration(minutes: 0),
      required this.onChange,
      this.width,
      this.height,
      this.durationPickerMode});

  @override
  _DurationPicker createState() => _DurationPicker();
}

class _DurationPicker extends State<DurationPicker> {
  late DurationPickerMode currentDurationType;
  var boxShadow =
      BoxShadow(color: Color(0x07000000), offset: Offset(3, 0), blurRadius: 12);
  int days = 0;
  int hours = 0;
  int minutes = 0;
  int seconds = 0;
  int milliseconds = 0;
  int microseconds = 0;
  int currentValue = 0;
  Duration duration = Duration();
  double? width;

  double? height;

  @override
  void initState() {
    super.initState();
    currentDurationType =
        widget.durationPickerMode ?? DurationPickerMode.Minute;
    currentValue = getCurrentValue();
    days = widget.duration.inDays;
    hours = (widget.duration.inHours) % Duration.hoursPerDay;
    minutes = widget.duration.inMinutes % Duration.minutesPerHour;
    seconds = widget.duration.inSeconds % Duration.secondsPerMinute;
    milliseconds =
        widget.duration.inMilliseconds % Duration.millisecondsPerSecond;
    microseconds =
        widget.duration.inMicroseconds % Duration.microsecondsPerMillisecond;
    width = widget.width ?? _kDurationPickerWidthLandscape;
    height = widget.height ?? _kDurationPickerHeightLandscape;
  }

  Widget build(BuildContext context) {
    _ScreenSize screenSize = getScreenSize(MediaQuery.of(context).size.width);
    return OrientationBuilder(builder: (context, orientation) {
      return Container(
          width: width,
          height: height,
          child: Row(children: [
            screenSize != _ScreenSize.mobile
                ? Expanded(
                    flex: 5, child: getDurationFields(context, orientation))
                : Container(),
            currentDurationType == DurationPickerMode.Day &&
                    screenSize != _ScreenSize.mobile
                ? Container()
                : Expanded(
                    flex: 5,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          screenSize == _ScreenSize.mobile
                              ? getCurrentSelectionFieldText()
                              : Container(),
                          screenSize == _ScreenSize.mobile &&
                                  currentDurationType == DurationPickerMode.Day
                              ? Column(children: [
                                  SizedBox(
                                    height: 80,
                                  ),
                                  _ShowTimeArgs(
                                    durationMode: DurationPickerMode.Day,
                                    onChanged: updateValue,
                                    onTextChanged: updateDurationFields,
                                    value: days,
                                    formatWidth: 2,
                                    desc: "days",
                                    isEditable: currentDurationType ==
                                        DurationPickerMode.Day,
                                    start: 0,
                                    end: -1,
                                  ),
                                  SizedBox(
                                    height: 80,
                                  )
                                ])
                              : Container(
                                  //decoration: BoxDecoration(border: Border.all(width: 2)),
                                  width: 300,
                                  height: 200,
                                  child: _Dial(
                                    value: currentValue,
                                    mode: currentDurationType,
                                    onChanged: updateDurationFields,
                                  ),
                                ),
                          getFields(),
                        ])),
          ]));
    });
  }

  Widget getFields() {
    return Flexible(
        child: Container(
            padding: EdgeInsets.only(left: 10, right: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                currentDurationType == DurationPickerMode.Day
                    ? Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(200),
                            color: Color(0x1E000000)),
                        child: Icon(
                          Icons.arrow_right_rounded,
                          color: Color(0x42000000),
                          size: 36,
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(200),
                            color: Colors.blueAccent),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                            hoverColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            onTap: () {
                              updateValue(currentDurationType.prev);
                            },
                            child: Icon(
                              Icons.arrow_left_rounded,
                              color: Colors.white,
                              size: 36,
                            )),
                      ),
                Text(
                  currentDurationType.name,
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                ),
                currentDurationType == DurationPickerMode.MicroSecond
                    ? Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(200),
                            color: Color(0x1E000000)),
                        child: Icon(
                          Icons.arrow_right_rounded,
                          color: Color(0x42000000),
                          size: 36,
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(200),
                            color: Colors.blueAccent),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                            hoverColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            onTap: () {
                              updateValue(currentDurationType.next);
                            },
                            child: Icon(
                              Icons.arrow_right_rounded,
                              color: Colors.white,
                              size: 36,
                            )),
                      ),
              ],
            )));
  }

  Widget getCurrentSelectionFieldText() {
    return Container(
        width: double.infinity,
        child: Text(
          "Select ".toUpperCase() +
              currentDurationType.name.toUpperCase(),
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
          textAlign: TextAlign.left,
        ));
  }

  Widget getDurationFields(BuildContext context, Orientation orientation) {
    return Container(
        padding: EdgeInsets.only(left: 10, right: 10),
        width: 100,
        child: Column(
          children: <Widget>[
            getCurrentSelectionFieldText(),
            SizedBox(
              height: 10,
            ),
            _ShowTimeArgs(
              durationMode: DurationPickerMode.Day,
              onChanged: updateValue,
              onTextChanged: updateDurationFields,
              value: days,
              formatWidth: 2,
              desc: "days",
              isEditable: currentDurationType == DurationPickerMode.Day,
              start: 0,
              end: -1,
            ),
            SizedBox(
              height: 6,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ShowTimeArgs(
                  durationMode: DurationPickerMode.Hour,
                  onChanged: updateValue,
                  onTextChanged: updateDurationFields,
                  value: hours,
                  formatWidth: 2,
                  desc: "hours",
                  isEditable: currentDurationType == DurationPickerMode.Hour,
                  start: 0,
                  end: 23,
                ),
                getColonWidget(),
                _ShowTimeArgs(
                  durationMode: DurationPickerMode.Minute,
                  onChanged: updateValue,
                  onTextChanged: updateDurationFields,
                  value: minutes,
                  formatWidth: 2,
                  desc: "minutes",
                  isEditable: currentDurationType == DurationPickerMode.Minute,
                  start: 0,
                  end: 59,
                ),
                getColonWidget(),
                _ShowTimeArgs(
                  durationMode: DurationPickerMode.Second,
                  onChanged: updateValue,
                  onTextChanged: updateDurationFields,
                  value: seconds,
                  formatWidth: 2,
                  desc: "seconds",
                  isEditable: currentDurationType == DurationPickerMode.Second,
                  start: 0,
                  end: 59,
                )
              ],
            ),
            SizedBox(
              height: 6,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ShowTimeArgs(
                  durationMode: DurationPickerMode.MilliSecond,
                  onChanged: updateValue,
                  onTextChanged: updateDurationFields,
                  value: milliseconds,
                  formatWidth: 3,
                  desc: "milliseconds",
                  isEditable:
                      currentDurationType == DurationPickerMode.MicroSecond,
                  start: 0,
                  end: 999,
                ),
                getColonWidget(),
                _ShowTimeArgs(
                  durationMode: DurationPickerMode.MicroSecond,
                  onChanged: updateValue,
                  onTextChanged: updateDurationFields,
                  value: microseconds,
                  formatWidth: 3,
                  desc: 'microseconds',
                  isEditable:
                      currentDurationType == DurationPickerMode.MicroSecond,
                  start: 0,
                  end: 999,
                )
              ],
            ),
            SizedBox(
              width: 2,
              height: 4,
            ),
            currentDurationType == DurationPickerMode.Day &&
                    orientation == Orientation.landscape
                ? getFields()
                : Container()
          ],
        ));
  }

  int getCurrentValue() {
    switch (currentDurationType) {
      case DurationPickerMode.Day:
        return days;
      case DurationPickerMode.Hour:
        return hours;
      case DurationPickerMode.Minute:
        return minutes;
      case DurationPickerMode.Second:
        return seconds;
      case DurationPickerMode.MilliSecond:
        return milliseconds;
      case DurationPickerMode.MicroSecond:
        return microseconds;
      default:
        return -1;
    }
  }

  void updateDurationFields(value) {
    setState(() {
      switch (currentDurationType) {
        case DurationPickerMode.Day:
          days = value;
          break;
        case DurationPickerMode.Hour:
          hours = value;
          break;
        case DurationPickerMode.Minute:
          minutes = value;
          break;
        case DurationPickerMode.Second:
          seconds = value;
          break;
        case DurationPickerMode.MilliSecond:
          milliseconds = value;
          break;
        case DurationPickerMode.MicroSecond:
          microseconds = value;
          break;
      }
      currentValue = value;
    });

    widget.onChange(Duration(
        days: days,
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
        microseconds: microseconds));
  }

  void updateValue(value) {
    setState(() {
      currentDurationType = value;
      currentValue = getCurrentValue();
      width = getWidth(currentDurationType);
    });
  }

  double? getWidth(durationType) {
    switch (durationType) {
      case DurationPickerMode.Day:
        return width! == _kDurationPickerWidthLandscape ? width! / 2 : width;
      default:
        return width == _kDurationPickerWidthLandscape ? width : width! * 2;
    }
  }

  Widget getColonWidget() {
    return Row(children: [
      SizedBox(
        width: 4,
      ),
      Text(
        ":",
        style:
            TextStyle(fontWeight: FontWeight.bold, fontSize: 28, height: 1.25),
      ),
      SizedBox(
        width: 4,
      )
    ]);
  }

  String getFormattedStringWithLeadingZeros(int number, int formatWidth) {
    var result = new StringBuffer();
    while (formatWidth > 0) {
      int temp = number % 10;
      result.write(temp);
      number = (number ~/ 10);
      formatWidth--;
    }
    return result.toString();
  }
}

class _ShowTimeArgs extends StatefulWidget {
  final int value;
  final int formatWidth;
  final String desc;
  final bool isEditable;
  final DurationPickerMode durationMode;
  final Function onChanged;
  final Function onTextChanged;
  final int start;
  final int end;

  _ShowTimeArgs(
      {required this.value,
      required this.formatWidth,
      required this.desc,
      required this.isEditable,
      required this.durationMode,
      required this.onChanged,
      required this.onTextChanged,
      required this.start,
      required this.end});

  @override
  _ShowTimeArgsState createState() => _ShowTimeArgsState();
}

class _ShowTimeArgsState extends State<_ShowTimeArgs> {
  TextEditingController? controller;
  var timerColor = Color(0x1E000000);
  var boxShadow;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller = getTextEditingController(getFormattedText());
  }

  @override
  void initState() {
    super.initState();
    controller = getTextEditingController(getFormattedText());
  }

  @override
  void didUpdateWidget(_ShowTimeArgs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      controller = getTextEditingController(getFormattedText());
    }
  }

  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Column(children: [
      widget.isEditable
          ? Container(
              width: getTextFormFieldWidth(widget.durationMode),
              height: 41,
              child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent) {
                      switch (event.logicalKey.keyId) {
                        case 4295426091: //Enter Key ID from keyboard
                          widget.onChanged(widget.durationMode.next);
                          break;
                        case 4295426130:
                          widget.onTextChanged(
                              (widget.value + 1) % (widget.end + 1) +
                                  widget.start);
                          break;
                        case 4295426129:
                          widget.onTextChanged(
                              (widget.value - 1) % (widget.end + 1) +
                                  widget.start);
                          break;
                      }
                    }
                  },
                  child: TextFormField(
                    onChanged: (text) {
                      if (text.trim() == "") {
                        text = "0";
                      }
                      widget.onTextChanged(int.parse(text));
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.deny('\n'),
                      FilteringTextInputFormatter.deny('\t'),
                      _DurationFieldsFormatter(
                        start: widget.start,
                        end: widget.end,
                        useFinal: widget.durationMode != DurationPickerMode.Day,
                      )
                    ],
                    style: TextStyle(fontSize: 20),
                    controller: controller,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.only(left: 10, right: 10),
                      filled: true,
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.transparent),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: colorScheme.error, width: 2.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: colorScheme.primary, width: 2.0),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: colorScheme.error, width: 2.0),
                      ),
                      errorStyle: const TextStyle(
                          fontSize: 0.0,
                          height:
                              0.0), // Prevent the error text from appearing.
                    ),
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    textAlign: TextAlign.center,
                  )))
          : InkWell(
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              focusColor: Colors.transparent,
              onTap: () async {
                widget.onChanged(widget.durationMode);
                timerColor = Color(0x1E000000);
              },
              onHover: (hoverCursor) {
                setState(() {
                  boxShadow = hoverCursor
                      ? BoxShadow(
                          color: Color(0x30004CBE),
                          offset: Offset(0, 6),
                          blurRadius: 12)
                      : BoxShadow(
                          color: Color(0x07000000),
                          offset: Offset(3, 0),
                          blurRadius: 12);
                  timerColor =
                      hoverCursor ? Color(0x32000000) : Color(0x1E000000);
                });
              },
              child: Container(
                constraints: BoxConstraints(maxWidth: 150),
                padding: EdgeInsets.only(left: 6, right: 6, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: timerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.durationMode != DurationPickerMode.Day
                      ? getFormattedStringWithLeadingZeros(
                          widget.value, widget.formatWidth)
                      : widget.value.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 28,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
      Text(
        widget.desc,
        style: TextStyle(fontSize: 12, height: 1.5),
      )
    ]);
  }

  double getTextFormFieldWidth(currentDurationField) {
    switch (currentDurationField) {
      case DurationPickerMode.Hour:
      case DurationPickerMode.Minute:
      case DurationPickerMode.Second:
        return 45;
      case DurationPickerMode.MilliSecond:
      case DurationPickerMode.MicroSecond:
        return 56;
      case DurationPickerMode.Day:
        return 100;
      default:
        return 0;
    }
  }

  String getFormattedText() {
    return widget.value.toString();
  }

  TextEditingController getTextEditingController(value) {
    return TextEditingController.fromValue(TextEditingValue(
        text: value, selection: TextSelection.collapsed(offset: value.length)));
  }

  String getFormattedStringWithLeadingZeros(int number, int formatWidth) {
    var result = new StringBuffer();
    while (formatWidth > 0) {
      int temp = number % 10;
      result.write(temp);
      number = (number ~/ 10);
      formatWidth--;
    }
    return result.toString().split('').reversed.join();
  }
}

class _DurationFieldsFormatter extends TextInputFormatter {
  final int? start;
  final int? end;
  final bool? useFinal;

  _DurationFieldsFormatter({this.start, this.end, this.useFinal});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String text = newValue.text;
    int selectionIndex = newValue.selection.end;
    int value = 0;
    try {
      if (text.trim() != "") {
        value = int.parse(text);
      }
    } catch (ex) {
      return oldValue;
    }

    if (value == 0) {
      return newValue;
    }

    if (!(start! <= value && (!useFinal! || value <= end!))) {
      return oldValue;
    }
    return newValue.copyWith(
      text: value.toString(),
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}
