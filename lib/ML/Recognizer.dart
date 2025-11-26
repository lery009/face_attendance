import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../api/api_service.dart';
import '../model/employee_match_response.dart';
import 'Recognition.dart';

class Recognizer {
  late Interpreter interpreter;
  late InterpreterOptions _interpreterOptions;
  static const int WIDTH = 160;
  static const int HEIGHT = 160;
  static const int OUTPUT = 512;
  final apiService = ApiService();

  // Recognition threshold - only accept matches with score >= this value
  // Lower values are MORE similar (cosine distance)
  // Typical good threshold: 0.8-1.0 for strict matching
  // Increased to 0.95 to prevent false positives
  static const double RECOGNITION_THRESHOLD = 0.95;

  @override
  String get modelName => 'assets/facenet.tflite';

  Recognizer({int? numThreads}) {
    _interpreterOptions = InterpreterOptions();

    if (numThreads != null) {
      _interpreterOptions.threads = numThreads;
    }
    loadModel();
  }

  Future<void> loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset(modelName);
    } catch (e) {
      // Silent fail - model loading error
    }
  }

  List<dynamic> imageToArray(img.Image inputImage){
    img.Image resizedImage = img.copyResize(inputImage!, width: WIDTH, height: HEIGHT);
    List<double> flattenedList = resizedImage.data!.expand((channel) => [channel.r, channel.g, channel.b]).map((value) => value.toDouble()).toList();
    Float32List float32Array = Float32List.fromList(flattenedList);
    int channels = 3;
    int height = HEIGHT;
    int width = WIDTH;
    Float32List reshapedArray = Float32List(1 * height * width * channels);
    for (int c = 0; c < channels; c++) {
      for (int h = 0; h < height; h++) {
        for (int w = 0; w < width; w++) {
          int index = c * height * width + h * width + w;
          reshapedArray[index] = (float32Array[c * height * width + h * width + w]-127.5)/127.5;
        }
      }
    }
    return reshapedArray.reshape([1,WIDTH,HEIGHT,3]);
  }

  Future<Recognition> recognize(img.Image image, Rect location) async {
    //TODO crop face from image resize it and convert it to float array
    var input = imageToArray(image);

    //TODO output array
    List output = List.filled(1*OUTPUT, 0).reshape([1,OUTPUT]);

    //TODO performs inference
    interpreter.run(input, output);

    //TODO convert dynamic list to double list
    List<double> outputArray = output.first.cast<double>();

    //TODO call API to match employee
    EmployeeMatchResponse? matchResponse = await apiService.matchEmployee(
      embedding: outputArray,
    );

    // Debug logging to see what the API is returning
    if (matchResponse != null) {
      print("🔍 Match Response: ${matchResponse.match.name}, Score: ${matchResponse.match.score.toStringAsFixed(3)}, isMatch: ${matchResponse.match.isMatch}");
    } else {
      print("🔍 No match response from API");
    }

    // Validate match with both server response AND client-side threshold
    if (matchResponse != null &&
        matchResponse.match.isMatch &&
        matchResponse.match.score >= RECOGNITION_THRESHOLD) {
      // Return recognized employee with full details
      print("✅ ACCEPTED: ${matchResponse.match.name} (Score: ${matchResponse.match.score.toStringAsFixed(3)} >= ${RECOGNITION_THRESHOLD})");
      return Recognition(
        matchResponse.match.name,
        location,
        outputArray,
        matchResponse.match.score,
      );
    } else {
      // Return unknown - either no match, or score too low
      if (matchResponse != null && matchResponse.match.isMatch) {
        print("❌ REJECTED: ${matchResponse.match.name} (Score: ${matchResponse.match.score.toStringAsFixed(3)} < ${RECOGNITION_THRESHOLD})");
      }
      return Recognition("Unknown", location, outputArray, 0.0);
    }
  }


  void close() {
    interpreter.close();
  }

}


