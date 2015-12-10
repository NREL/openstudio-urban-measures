// Here is the starting point for your application code.
// All stuff below is just to show you how it works. You can delete all of it.

// Use new ES6 modules syntax for everything.
import os from 'os'; // native node.js module
import { remote } from 'electron'; // native electron module
import jetpack from 'fs-jetpack'; // module loaded from npm
import { greet } from './hello_world/hello_world'; // code authored by you in this project
import env from './env';

console.log('Loaded environment variables:', env);

var app = remote.app;
var appDir = jetpack.cwd(app.getAppPath());

// Holy crap! This is browser window with HTML and stuff, but I can read
// here files like it is node.js! Welcome to Electron world :)
//console.log('The author if this app is:', appDir.read('package.json', 'json').author);

document.addEventListener('DOMContentLoaded', function() {

  console.log('DOMContentLoaded');
  
  // from https://github.com/AnalyticalGraphicsInc/cesium/blob/1.16/Apps/CesiumViewer/CesiumViewer.js

  var loadingIndicator = document.getElementById('loadingIndicator');
  var cesiumContainer = document.getElementById('cesiumContainer');

  Cesium.BingMapsApi.defaultKey = 'OS7Aeoxh8uTsCDK8Ei7i~adKTbclqLHxxcbR5EHd15A~ArarK4g2lDPp3--tA7K-lNaVf4miYu4kJOgNISo7EbiWvsQZ67e5JcEHik2w1RFK';

  var viewer;
  try {
    viewer = new Cesium.Viewer('cesiumContainer', {});
  } catch (exception) {
    var message = Cesium.formatError(exception);
    console.error(message);
    if (!document.querySelector('.cesium-widget-errorPanel')) {
      window.alert(message);
    }
    loadingIndicator.style.display = 'none';
  }
  
  //viewer.extend(Cesium.viewerCesiumInspectorMixin);

  //var showLoadError = function(name, error) {
  //  var title = 'An error occurred while loading the file: ' + name;
  //  var message = 'An error occurred while loading the file, which may indicate that it is invalid.  A detailed error report is below:';
  //  viewer.cesiumWidget.showErrorPanel(title, message, error);
  //};
  //viewer.extend(Cesium.viewerDragDropMixin);
  //viewer.dropError.addEventListener(function(viewerArg, name, error) {
  //  showLoadError(name, error);
  //});

  var scene = viewer.scene;
  var context = scene.context;
  //context.validateShaderProgram = true;
  //context.validateFramebuffer = true;
  //context.logShaderCompilation = true;
  //context.throwOnWebGLError = true;

  //scene.debugShowFramesPerSecond = true;

  loadingIndicator.style.display = 'none';

});