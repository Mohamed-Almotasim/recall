import 'dart:io';

Future<String> loadSeedFromDisk(String path) => File(path).readAsString();
