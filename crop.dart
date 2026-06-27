import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon.jpg');
  final bytes = file.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) return;
  
  // Crop 5% from each side to remove slight whitespace
  final cropX = (image.width * 0.05).toInt();
  final cropY = (image.height * 0.05).toInt();
  final cropW = (image.width * 0.90).toInt();
  final cropH = (image.height * 0.90).toInt();

  var cropped = img.copyCrop(image, x: cropX, y: cropY, width: cropW, height: cropH);
  
  // Create a new transparent image of the same size
  var rounded = img.Image(width: cropped.width, height: cropped.height, numChannels: 4);
  img.fill(rounded, color: img.ColorRgba8(0, 0, 0, 0));

  double radius = cropped.width * 0.2; // 20% corner radius

  for (int y = 0; y < cropped.height; y++) {
    for (int x = 0; x < cropped.width; x++) {
      bool isInside = true;

      // Top-left
      if (x < radius && y < radius) {
        if (pow(x - radius, 2) + pow(y - radius, 2) > pow(radius, 2)) isInside = false;
      }
      // Top-right
      else if (x > cropped.width - radius && y < radius) {
        if (pow(x - (cropped.width - radius), 2) + pow(y - radius, 2) > pow(radius, 2)) isInside = false;
      }
      // Bottom-left
      else if (x < radius && y > cropped.height - radius) {
        if (pow(x - radius, 2) + pow(y - (cropped.height - radius), 2) > pow(radius, 2)) isInside = false;
      }
      // Bottom-right
      else if (x > cropped.width - radius && y > cropped.height - radius) {
        if (pow(x - (cropped.width - radius), 2) + pow(y - (cropped.height - radius), 2) > pow(radius, 2)) isInside = false;
      }

      if (isInside) {
        var pixel = cropped.getPixel(x, y);
        rounded.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, 255);
      }
    }
  }

  File('assets/icon.png').writeAsBytesSync(img.encodePng(rounded));
  print('Rounded transparent image saved to assets/icon.png.');
}
