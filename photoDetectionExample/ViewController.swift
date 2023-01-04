//
//  ViewController.swift
//  objectDetectionWithPhoto
//
//  Created by Türker Alan on 3.01.2023.
//

import AVFoundation
import UIKit
import TensorFlowLiteTaskVision

struct ConstantsDefault {
  static let modelType: ModelType = .efficientDetLite0
  static let threadCount = 1
  static let scoreThreshold: Float = 0.4
  static let maxResults: Int = 3
  static let theadCountLimit = 10
}

class ViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    
    private var image: UIImage?
    private var objectDetectionHelper: ObjectDetectionHelper? = ObjectDetectionHelper(
        modelFileInfo: ConstantsDefault.modelType.modelFileInfo,
        threadCount: ConstantsDefault.threadCount,
        scoreThreshold: ConstantsDefault.scoreThreshold,
        maxResults: ConstantsDefault.maxResults
    )
    
    private var label = UILabel()
    
    private var result: Result?
    private var inferenceViewController: InferenceViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(label)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configureVC()
    }
    
    // MARK: Constants
    private let displayFont = UIFont.systemFont(ofSize: 14.0, weight: .medium)
    private let edgeOffset: CGFloat = 2.0
    private let labelOffset: CGFloat = 10.0
    private let animationDuration = 0.5
    private let collapseTransitionThreshold: CGFloat = -30.0
    private let expandTransitionThreshold: CGFloat = 30.0
    private let colors = [
      UIColor.red,
      UIColor(displayP3Red: 90.0 / 255.0, green: 200.0 / 255.0, blue: 250.0 / 255.0, alpha: 1.0),
      UIColor.green,
      UIColor.orange,
      UIColor.blue,
      UIColor.purple,
      UIColor.magenta,
      UIColor.yellow,
      UIColor.cyan,
      UIColor.brown,
    ]
    
    func configureVC() {
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.delegate = self
        present(vc, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let image = info[.originalImage] as? UIImage else {
            print("No image found")
            return
        }
        
        print(image.cgImage?.pixelFormatInfo)
        
        // print out the image size as a test
        self.image = image
        
       
        let resizedImage = image.resize(to: CGSize(width: 640, height: 640))
        
        if let pixelBuffer = resizedImage.pixelBuffer() {
            detect(pixelBuffer: pixelBuffer)
        }
    }
    
    func detect(pixelBuffer: CVPixelBuffer) {
//        let time = Date.
        result = self.objectDetectionHelper?.detect(frame: pixelBuffer)
        
        guard let displayResult = result else {
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        DispatchQueue.main.async {
            
            // Display results by handing off to the InferenceViewController
            self.inferenceViewController?.resolution = CGSize(width: width, height: height)
            
            var inferenceTime: Double = 0
            if let resultInferenceTime = self.result?.inferenceTime {
                inferenceTime = resultInferenceTime
            }
            self.inferenceViewController?.inferenceTime = inferenceTime
            self.inferenceViewController?.tableView.reloadData()
            
            // Draws the bounding boxes and displays class names and confidence scores.
            self.drawAfterPerformingCalculations(
                onDetections: displayResult.detections,
                withImageSize: CGSize(width: CGFloat(width), height: CGFloat(height)))
        }
    }
    
    /**
     This method takes the results, translates the bounding box rects to the current view, draws the bounding boxes, classNames and confidence scores of inferences.
     */
    func drawAfterPerformingCalculations(
        onDetections detections: [Detection], withImageSize imageSize: CGSize
    ) {
        
        
        guard !detections.isEmpty else {
            return
        }
        
        var objectOverlays: [ObjectOverlay] = []
        
        for detection in detections {
            
            guard let category = detection.categories.first else { continue }
            
            let objectDescription = String(
                format: "\(category.label ?? "Unknown") (%.2f)",
                category.score)
            
            let displayColor = colors[category.index % colors.count]
            
            let size = objectDescription.size(withAttributes: [.font: self.displayFont])
            
            let objectOverlay = ObjectOverlay(
                name: objectDescription, nameStringSize: size,
                color: displayColor,
                font: self.displayFont)
            
            print("name: \(objectOverlay.name)")
            print("nameStringSize: \(objectOverlay.nameStringSize)")
        }
        
    }
    
}

enum ModelType: CaseIterable {
  case efficientDetLite0
  case efficientDetLite1
  case efficientDetLite2
  case ssdMobileNetV1

  var modelFileInfo: FileInfo {
    switch self {
    case .ssdMobileNetV1:
      return FileInfo("ssd_mobilenet_v1", "tflite")
    case .efficientDetLite0:
      return FileInfo("efficientdet_lite0", "tflite")
    case .efficientDetLite1:
      return FileInfo("efficientdet_lite1", "tflite")
    case .efficientDetLite2:
      return FileInfo("efficientdet_lite2", "tflite")
    }
  }

  var title: String {
    switch self {
    case .ssdMobileNetV1:
      return "SSD-MobileNetV1"
    case .efficientDetLite0:
      return "EfficientDet-Lite0"
    case .efficientDetLite1:
      return "EfficientDet-Lite1"
    case .efficientDetLite2:
      return "EfficientDet-Lite2"
    }
  }
}



extension UIImage {

    func resize(to newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: newSize.width, height: newSize.height), true, 1.0)
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return resizedImage
    }

    func cropToSquare() -> UIImage? {
        guard let cgImage = self.cgImage else {
            return nil
        }
        var imageHeight = self.size.height
        var imageWidth = self.size.width

        if imageHeight > imageWidth {
            imageHeight = imageWidth
        }
        else {
            imageWidth = imageHeight
        }

        let size = CGSize(width: imageWidth, height: imageHeight)

        let x = ((CGFloat(cgImage.width) - size.width) / 2).rounded()
        let y = ((CGFloat(cgImage.height) - size.height) / 2).rounded()

        let cropRect = CGRect(x: x, y: y, width: size.height, height: size.width)
        if let croppedCgImage = cgImage.cropping(to: cropRect) {
            return UIImage(cgImage: croppedCgImage, scale: 0, orientation: self.imageOrientation)
        }

        return nil
    }

    func pixelBuffer() -> CVPixelBuffer? {
        let width = self.size.width
        let height = self.size.height
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(width),
                                         Int(height),
                                         kCVPixelFormatType_32BGRA,
                                         attrs,
                                         &pixelBuffer)

        guard let resultPixelBuffer = pixelBuffer, status == kCVReturnSuccess else {
            return nil
        }

        CVPixelBufferLockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(resultPixelBuffer)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pixelData,
                                      width: Int(width),
                                      height: Int(height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(resultPixelBuffer),
                                      space: rgbColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
                                        return nil
        }

        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context)
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

        return resultPixelBuffer
    }
}
