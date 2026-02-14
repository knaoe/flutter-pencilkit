import Flutter
import PencilKit
import UIKit

class FLPencilKitFactory: NSObject, FlutterPlatformViewFactory {
  private var messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    FLPencilKit(
      frame: frame,
      viewIdentifier: viewId,
      arguments: args,
      binaryMessenger: messenger
    )
  }
}

enum FLPencilKitError: Error {
  case invalidArgument
}

class FLPencilKit: NSObject, FlutterPlatformView {
  private var _view: UIView
  private var methodChannel: FlutterMethodChannel
  func view() -> UIView { _view }

  init(
    frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?,
    binaryMessenger messenger: FlutterBinaryMessenger?
  ) {
    methodChannel = FlutterMethodChannel(
      name: "plugins.mjstudio/flutter_pencil_kit_\(viewId)",
      binaryMessenger: messenger!
    )
    if #available(iOS 13.0, *) {
      let aspectRatio: CGFloat
      var backgroundImage: UIImage?
      if let argsDict = args as? [String: Any] {
        aspectRatio = (argsDict["aspectRatio"] as? Double)
          .map { CGFloat($0) } ?? 1.0
        if let imageData = argsDict["imageData"] as? FlutterStandardTypedData {
          backgroundImage = UIImage(data: imageData.data)
        }
      } else {
        aspectRatio = 1.0
      }
      _view = PencilKitView(
        frame: frame,
        methodChannel: methodChannel,
        aspectRatio: aspectRatio,
        backgroundImage: backgroundImage
      )
    } else {
      _view = UIView(frame: frame)
    }
    super.init()
    methodChannel.setMethodCallHandler(onMethodCall)
  }

  private func onMethodCall(call: FlutterMethodCall, result: FlutterResult) {
    if #available(iOS 13.0, *) {
      guard let pencilKitView = _view as? PencilKitView else { return }
      switch call.method {
      case "clear":
        pencilKitView.clear()
        result(nil)
      case "redo":
        pencilKitView.redo()
        result(nil)
      case "undo":
        pencilKitView.undo()
        result(nil)
      case "show":
        pencilKitView.show()
        result(nil)
      case "hide":
        pencilKitView.hide()
        result(nil)
      case "setPKTool":
        pencilKitView.setPKTool(properties: call.arguments as! [String: Any])
        result(nil)
      case "save":
        save(pencilKitView: pencilKitView, call: call, result: result)
      case "load":
        load(pencilKitView: pencilKitView, call: call, result: result)
      case "getBase64Data":
        getBase64Data(pencilKitView: pencilKitView, call: call, result: result)
      case "getBase64PngData":
        getBase64PngData(pencilKitView: pencilKitView, call: call, result: result)
      case "getBase64JpegData":
        getBase64JpegData(pencilKitView: pencilKitView, call: call, result: result)
      case "loadBase64Data":
        loadBase64Data(pencilKitView: pencilKitView, call: call, result: result)
      case "applyProperties":
        pencilKitView.applyProperties(properties: call.arguments as! [String: Any?])
        result(nil)
      default:
        break
      }
    }
  }

  @available(iOS 13, *)
  private func save(pencilKitView: PencilKitView, call: FlutterMethodCall, result: FlutterResult) {
    do {
      let (url, withBase64Data) = parseArguments(call.arguments)
      let base64Data = try pencilKitView.save(url: url, withBase64Data: withBase64Data)
      result(base64Data)
    } catch {
      result(FlutterError(code: "NATIVE_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  @available(iOS 13, *)
  private func load(pencilKitView: PencilKitView, call: FlutterMethodCall, result: FlutterResult) {
    do {
      let (url, withBase64Data) = parseArguments(call.arguments)
      let base64Data = try pencilKitView.load(url: url, withBase64Data: withBase64Data)
      result(base64Data)
    } catch {
      result(FlutterError(code: "NATIVE_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  @available(iOS 13, *)
  private func getBase64Data(
    pencilKitView: PencilKitView,
    call: FlutterMethodCall,
    result: FlutterResult
  ) {
    let base64Data = pencilKitView.getBase64Data()
    result(base64Data)
  }

  @available(iOS 13, *)
  private func getBase64PngData(
    pencilKitView: PencilKitView,
    call: FlutterMethodCall,
    result: FlutterResult
  ) {
    if let base64Data = pencilKitView.getBase64PngData(scale: (call.arguments as! [Double])[0]) {
      result(base64Data)
    } else {
      result(FlutterError(code: "NATIVE_ERROR", message: "getBase64PngData failed", details: nil))
    }
  }

  @available(iOS 13, *)
  private func getBase64JpegData(
    pencilKitView: PencilKitView,
    call: FlutterMethodCall,
    result: FlutterResult
  ) {
    if let base64Data = pencilKitView.getBase64JpegData(
      scale: (call.arguments as! [Double])[0],
      compression: (call.arguments as! [Double])[1]
    ) {
      result(base64Data)
    } else {
      result(FlutterError(code: "NATIVE_ERROR", message: "getBase64JpegData failed", details: nil))
    }
  }

  @available(iOS 13, *)
  private func loadBase64Data(
    pencilKitView: PencilKitView,
    call: FlutterMethodCall,
    result: FlutterResult
  ) {
    do {
      let base64Data = call.arguments as! String
      try pencilKitView.loadBase64Data(base64Data: base64Data)
      result(nil)
    } catch {
      result(FlutterError(code: "NATIVE_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  private func parseArguments(_ arguments: Any?) -> (URL, Bool) {
    guard let arguments = arguments as? [Any] else { fatalError() }
    return (URL(fileURLWithPath: arguments[0] as! String), arguments[1] as! Bool)
  }
}

// MARK: - Canvas factory (no zoom — zoom is handled by the wrapper scroll view)

@available(iOS 13.0, *)
private func createCanvasView(delegate: PKCanvasViewDelegate) -> PKCanvasView {
  let v = PKCanvasView()
  v.drawing = PKDrawing()
  v.delegate = delegate
  v.alwaysBounceVertical = false
  v.alwaysBounceHorizontal = false
  v.isScrollEnabled = false
  v.showsVerticalScrollIndicator = false
  v.showsHorizontalScrollIndicator = false
  v.minimumZoomScale = 1.0
  v.maximumZoomScale = 1.0
  v.contentInsetAdjustmentBehavior = .never
  if #unavailable(iOS 14.0) {
    v.allowsFingerDrawing = true
  }
  v.backgroundColor = .clear
  v.isOpaque = false
  return v
}

// MARK: - PencilKitView
//
// View hierarchy:
//   PencilKitView (self)
//     └─ zoomScrollView  (handles pinch-to-zoom & two-finger pan)
//          └─ zoomContentView  (viewForZooming — scales as a unit)
//               ├─ backgroundImageView
//               └─ canvasView  (PKCanvasView, no transform, no zoom)
//
// By keeping the external CGAffineTransform OFF the PKCanvasView and
// delegating zoom to a plain UIScrollView whose bounds == visual size,
// the zoom center is always correct (finger-centric).

@available(iOS 13.0, *)
private class PencilKitView: UIView {
  private lazy var canvasView: PKCanvasView = createCanvasView(delegate: self)

  private var toolPickerForIos14: PKToolPicker? = nil
  private var toolPicker: PKToolPicker? {
    if #available(iOS 14.0, *) {
      if toolPickerForIos14 == nil {
        toolPickerForIos14 = PKToolPicker()
      }
      return toolPickerForIos14!
    } else {
      guard let window = UIApplication.shared.windows.first,
            let toolPicker = PKToolPicker.shared(for: window) else { return nil }
      return toolPicker
    }
  }

  private let channel: FlutterMethodChannel
  private let canonicalSize: CGSize
  private let backgroundImageView: UIImageView
  private let zoomScrollView = UIScrollView()
  private let zoomContentView = UIView()
  private var toolPickerVisible = false

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("Not Implemented")
  }

  override init(frame: CGRect) {
    fatalError("Not Implemented")
  }

  init(
    frame: CGRect,
    methodChannel: FlutterMethodChannel,
    aspectRatio: CGFloat,
    backgroundImage: UIImage?
  ) {
    let w: CGFloat = 1024
    canonicalSize = CGSize(width: w, height: w / max(aspectRatio, 0.01))
    channel = methodChannel

    backgroundImageView = UIImageView(image: backgroundImage)
    backgroundImageView.contentMode = .scaleToFill
    backgroundImageView.isUserInteractionEnabled = false

    super.init(frame: frame)

    // -- Zoom scroll view (handles pinch-to-zoom) --
    zoomScrollView.showsVerticalScrollIndicator = false
    zoomScrollView.showsHorizontalScrollIndicator = false
    zoomScrollView.contentInsetAdjustmentBehavior = .never
    zoomScrollView.delaysContentTouches = false
    // Two-finger pan only so single-finger drawing is unaffected.
    zoomScrollView.panGestureRecognizer.minimumNumberOfTouches = 2
    zoomScrollView.delegate = self

    // -- Zoomable content (background + canvas at canonical size) --
    let contentFrame = CGRect(origin: .zero, size: canonicalSize)
    zoomContentView.frame = contentFrame
    backgroundImageView.frame = contentFrame
    canvasView.frame = contentFrame

    zoomContentView.addSubview(backgroundImageView)
    zoomContentView.addSubview(canvasView)
    zoomScrollView.addSubview(zoomContentView)
    zoomScrollView.contentSize = canonicalSize
    addSubview(zoomScrollView)

    toolPicker?.addObserver(canvasView)
    toolPicker?.addObserver(self)
  }

  // MARK: Layout

  override func layoutSubviews() {
    super.layoutSubviews()
    let containerSize = bounds.size
    guard containerSize.width > 0, containerSize.height > 0 else { return }

    zoomScrollView.frame = bounds

    let fitScale = containerSize.width / canonicalSize.width
    zoomScrollView.minimumZoomScale = fitScale
    zoomScrollView.maximumZoomScale = fitScale * 4.0

    // On first layout (or if somehow below fit), snap to fit.
    if zoomScrollView.zoomScale < fitScale {
      zoomScrollView.zoomScale = fitScale
    }

    centerZoomContent()
  }

  /// Center the content view when it is smaller than the scroll viewport
  /// (i.e. at minimum zoom the content may not fill the scroll view).
  private func centerZoomContent() {
    let boundsSize = zoomScrollView.bounds.size
    let contentSize = zoomScrollView.contentSize

    let xOffset = max(0, (boundsSize.width - contentSize.width) / 2)
    let yOffset = max(0, (boundsSize.height - contentSize.height) / 2)

    zoomContentView.frame.origin = CGPoint(x: xOffset, y: yOffset)
  }

  private func addAndPositionCanvasView() {
    canvasView.frame = CGRect(origin: .zero, size: canonicalSize)
    zoomContentView.addSubview(canvasView)
  }

  // MARK: Lifecycle

  deinit {
    toolPicker?.removeObserver(canvasView)
    toolPicker?.removeObserver(self)
  }

  // MARK: Drawing actions

  func clear() {
    canvasView.drawing = PKDrawing()
  }

  func undo() {
    canvasView.undoManager?.undo()
  }

  func redo() {
    canvasView.undoManager?.redo()
  }

  // MARK: Tool picker

  func show() {
    toolPickerVisible = true
    toolPicker?.setVisible(true, forFirstResponder: canvasView)
    if !canvasView.becomeFirstResponder() {
      DispatchQueue.main.async { [weak self] in
        self?.canvasView.becomeFirstResponder()
      }
    }
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil, toolPickerVisible {
      canvasView.becomeFirstResponder()
    }
  }

  func hide() {
    toolPickerVisible = false
    toolPicker?.setVisible(false, forFirstResponder: canvasView)
  }

  // MARK: PKTool

  func setPKTool(properties: [String: Any]) {
    let inputToolType = properties["toolType"] as! String
    var width: CGFloat?
    if let _width = properties["width"] as? Double {
      width = CGFloat(truncating: NSNumber(value: _width))
    }
    var color = UIColor.black
    if let _color = properties["color"] as? Int {
      color = UIColor(hex: _color)
    }
    switch inputToolType {
    case "pen":
      canvasView.tool = PKInkingTool(.pen, color: color, width: width)
    case "pencil":
      canvasView.tool = PKInkingTool(.pencil, color: color, width: width)
    case "marker":
      canvasView.tool = PKInkingTool(.marker, color: color, width: width)
    case "monoline":
      if #available(iOS 17.0, *) {
        canvasView.tool = PKInkingTool(.monoline, color: color, width: width)
      }
    case "fountainPen":
      if #available(iOS 17.0, *) {
        canvasView.tool = PKInkingTool(.fountainPen, color: color, width: width)
      }
    case "watercolor":
      if #available(iOS 17.0, *) {
        canvasView.tool = PKInkingTool(.watercolor, color: color, width: width)
      }
    case "crayon":
      if #available(iOS 17.0, *) {
        canvasView.tool = PKInkingTool(.crayon, color: color, width: width)
      }
    case "eraserVector":
      if #available(iOS 16.4, *) {
        canvasView
          .tool = width != nil ? PKEraserTool(.vector, width: width!) : PKEraserTool(.vector)
      } else {
        canvasView.tool = PKEraserTool(.vector)
      }
    case "eraserBitmap":
      if #available(iOS 16.4, *) {
        canvasView
          .tool = width != nil ? PKEraserTool(.bitmap, width: width!) : PKEraserTool(.bitmap)
      } else {
        canvasView.tool = PKEraserTool(.bitmap)
      }
    case "eraserFixedWidthBitmap":
      if #available(iOS 16.4, *) {
        canvasView
          .tool = width != nil ? PKEraserTool(.fixedWidthBitmap, width: width!) :
          PKEraserTool(.bitmap)
      }
    default:
      break
    }
    toolPicker?.selectedTool = canvasView.tool
  }

  // MARK: Persistence

  func save(url: URL, withBase64Data: Bool) throws -> String? {
    let data = canvasView.drawing.dataRepresentation()
    try data.write(to: url)
    if withBase64Data {
      return data.base64EncodedString()
    }
    return nil
  }

  func load(url: URL, withBase64Data: Bool) throws -> String? {
    let data = try Data(contentsOf: url)
    let drawing = try PKDrawing(data: data)

    let newCanvasView = createCanvasView(delegate: self)
    newCanvasView.drawing = drawing
    canvasView.removeFromSuperview()
    synchronizeCanvasViewProperties(old: canvasView, new: newCanvasView)
    canvasView = newCanvasView
    addAndPositionCanvasView()

    if withBase64Data {
      return drawing.dataRepresentation().base64EncodedString()
    }
    return nil
  }

  func getBase64Data() -> String {
    canvasView.drawing.dataRepresentation().base64EncodedString()
  }

  func getBase64PngData(scale: Double) -> String? {
    let image = canvasView.drawing.image(
      from: CGRect(origin: .zero, size: canonicalSize),
      scale: scale
    )
    return image.pngData()?.base64EncodedString()
  }

  func getBase64JpegData(scale: Double, compression: Double) -> String? {
    let image = canvasView.drawing.image(
      from: CGRect(origin: .zero, size: canonicalSize),
      scale: scale
    )
    return image.jpegData(compressionQuality: compression)?.base64EncodedString()
  }

  func loadBase64Data(base64Data: String) throws {
    let data = Data(base64Encoded: base64Data)!
    let drawing = try PKDrawing(data: data)

    let newCanvasView = createCanvasView(delegate: self)
    newCanvasView.drawing = drawing
    canvasView.removeFromSuperview()
    synchronizeCanvasViewProperties(old: canvasView, new: newCanvasView)
    canvasView = newCanvasView
    addAndPositionCanvasView()
  }

  // MARK: Properties

  func applyProperties(properties: [String: Any?]) {
    if let alwaysBounceVertical = properties["alwaysBounceVertical"] as? Bool {
      canvasView.alwaysBounceVertical = alwaysBounceVertical
    }
    if let alwaysBounceHorizontal = properties["alwaysBounceHorizontal"] as? Bool {
      canvasView.alwaysBounceHorizontal = alwaysBounceHorizontal
    }
    if let isRulerActive = properties["isRulerActive"] as? Bool {
      canvasView.isRulerActive = isRulerActive
    }
    if #available(iOS 14.0, *), let drawingPolicy = properties["drawingPolicy"] as? Int {
      canvasView
        .drawingPolicy = PKCanvasViewDrawingPolicy(rawValue: UInt(drawingPolicy)) ?? .default
    }
    if let isOpaque = properties["isOpaque"] as? Bool {
      canvasView.isOpaque = isOpaque
    }
    if let backgroundColor = properties["backgroundColor"] as? Int {
      canvasView.backgroundColor = UIColor(hex: backgroundColor)
    }
    if let userInterfaceStyle = properties["userInterfaceStyle"] as? Int {
      canvasView.overrideUserInterfaceStyle = UIUserInterfaceStyle(
        rawValue: userInterfaceStyle
      ) ?? .unspecified
    }
  }

  private func synchronizeCanvasViewProperties(old: PKCanvasView, new: PKCanvasView) {
    if let toolPicker {
      toolPicker.removeObserver(old)
      toolPicker.addObserver(new)
      toolPicker.setVisible(toolPickerVisible, forFirstResponder: new)
    }

    new.alwaysBounceVertical = old.alwaysBounceVertical
    new.alwaysBounceHorizontal = old.alwaysBounceHorizontal
    new.isRulerActive = old.isRulerActive
    if #available(iOS 14.0, *) {
      new.drawingPolicy = old.drawingPolicy
    }
    new.isOpaque = old.isOpaque
    new.backgroundColor = old.backgroundColor
    new.overrideUserInterfaceStyle = old.overrideUserInterfaceStyle

    if toolPicker?.isVisible == true {
      new.becomeFirstResponder()
    }
  }
}

// MARK: - UIScrollViewDelegate (zoom wrapper) + PKCanvasViewDelegate

@available(iOS 13.0, *)
extension PencilKitView: PKCanvasViewDelegate {
  // Called for zoomScrollView (canvasView has zoom disabled).
  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    if scrollView === zoomScrollView {
      return zoomContentView
    }
    return nil
  }

  func scrollViewDidZoom(_ scrollView: UIScrollView) {
    if scrollView === zoomScrollView {
      centerZoomContent()
    }
  }

  // PKCanvasView delegate callbacks
  func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
    channel.invokeMethod("canvasViewDidBeginUsingTool", arguments: nil)
  }

  func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
    channel.invokeMethod("canvasViewDidEndUsingTool", arguments: nil)
  }

  func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
    channel.invokeMethod("canvasViewDrawingDidChange", arguments: nil)
  }

  func canvasViewDidFinishRendering(_ canvasView: PKCanvasView) {
    channel.invokeMethod("canvasViewDidFinishRendering", arguments: nil)
  }
}

@available(iOS 13.0, *)
extension PencilKitView: PKToolPickerObserver {
  func toolPickerVisibilityDidChange(_ toolPicker: PKToolPicker) {
    channel.invokeMethod("toolPickerVisibilityDidChange", arguments: toolPicker.isVisible)
  }

  func toolPickerIsRulerActiveDidChange(_ toolPicker: PKToolPicker) {
    channel.invokeMethod("toolPickerIsRulerActiveDidChange", arguments: toolPicker.isRulerActive)
  }

  func toolPickerFramesObscuredDidChange(_ toolPicker: PKToolPicker) {
    channel.invokeMethod("toolPickerFramesObscuredDidChange", arguments: nil)
  }

  func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) {
    channel.invokeMethod("toolPickerSelectedToolDidChange", arguments: nil)
  }
}

extension UIColor {
  convenience init(hex: Int) {
    let alpha = Double((hex >> 24) & 0xFF) / 255
    let red = Double((hex >> 16) & 0xFF) / 255
    let green = Double((hex >> 8) & 0xFF) / 255
    let blue = Double((hex >> 0) & 0xFF) / 255

    self.init(red: red, green: green, blue: blue, alpha: alpha)
  }
}
