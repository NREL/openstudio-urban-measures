// Here is the starting point for your application code.
// All stuff below is just to show you how it works. You can delete all of it.

// Use new ES6 modules syntax for everything.
import os from 'os'; // native node.js module
import { remote } from 'electron'; // native electron module
import jetpack from 'fs-jetpack'; // module loaded from npm
import { greet } from './hello_world/hello_world'; // code authored by you in this project
import env from './env';

//console.log('Loaded environment variables:', env);

var app = remote.app;
var appDir = jetpack.cwd(app.getAppPath());
var city = appDir.read('city.json', 'json');

function imageryError(arg1) {
  console.log('imageryError');
  console.log(arg1);
}

function polygonEntity(polygon, extrudedHeight){
  var outer_points = [];
  var holes = [];

  for (let point of polygon['points']){
    outer_points.push(point['x']);
    outer_points.push(point['y']);
  }
  
  var result = {
    polygon : {
      hierarchy : {
        positions : Cesium.Cartesian3.fromDegreesArray(outer_points),
        holes : holes
      },
      extrudedHeight: extrudedHeight,
      material : Cesium.Color.RED.withAlpha(0.5),
      fill : true,
      outline : true,
      outlineColor : Cesium.Color.WHITE
    }
  };
  
  return result;
}

function drawBuilding(viewer, building) {

  var height = building['roof_elevation'] - building['surface_elevation'];
  
  for (let polygon of building['footprint']['polygons']){
    if (polygon['coordinate_system'] == "WGS 84"){
      var entity = polygonEntity(polygon, height);
      entity['name'] = building['name'];
      entity['description'] = building['space_type'];
      viewer.entities.add(entity);
    }
  }
}

document.addEventListener('DOMContentLoaded', function() {

  // from https://github.com/AnalyticalGraphicsInc/cesium/blob/1.16/Apps/CesiumViewer/CesiumViewer.js

  var loadingIndicator = document.getElementById('loadingIndicator');
  var cesiumContainer = document.getElementById('cesiumContainer');

  var bingKey = 'OS7Aeoxh8uTsCDK8Ei7i~adKTbclqLHxxcbR5EHd15A~ArarK4g2lDPp3--tA7K-lNaVf4miYu4kJOgNISo7EbiWvsQZ67e5JcEHik2w1RFK';
  Cesium.BingMapsApi.defaultKey = bingKey;
  
  var imageryErrorEvent = new Cesium.Event();
  imageryErrorEvent.addEventListener(imageryError);

  var imageryProvider = new Cesium.BingMapsImageryProvider({
          url : "https://dev.virtualearth.net/",
          //tileProtocol: "http",
          tileDiscardPolicy: new Cesium.NeverTileDiscardPolicy(),
          errorEvent: imageryErrorEvent,
          key: bingKey
      });
  
  //var imageryProvider = new Cesium.OpenStreetMapImageryProvider({
  //        url : "//a.tile.openstreetmap.org/"
  //    });

  var viewer;
  try {
    viewer = new Cesium.Viewer('cesiumContainer', {            
            imageryProvider : imageryProvider,
            baseLayerPicker : true,
            scene3DOnly : false,
            sceneModePicker: false,
            homeButton: false,
            baseLayerPicker: false
          });
    viewer._geocoder._viewModel._url = 'http://dev.virtualearth.net/';
  } catch (exception) {
    var message = Cesium.formatError(exception);
    console.error(message);
    if (!document.querySelector('.cesium-widget-errorPanel')) {
      window.alert(message);
    }
    loadingIndicator.style.display = 'none';
    return;
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

  scene.debugShowFramesPerSecond = true;
  
  loadingIndicator.style.display = 'none';
  
  var region_points = city['region']['polygon']['points'];
  
  var ellipsoid = Cesium.Ellipsoid.WGS84;
  var west = Cesium.Math.toRadians(region_points[0]['x']);
  var south = Cesium.Math.toRadians(region_points[0]['y']);
  var east = Cesium.Math.toRadians(region_points[2]['x']);
  var north = Cesium.Math.toRadians(region_points[2]['y']);

  var extent = new Cesium.Rectangle(west, south, east, north);
  
  
  scene.sceneMode = Cesium.SceneMode.SCENE2D;
  
  // Show the rectangle.  Not required; just for show.
  viewer.entities.add({
    rectangle : {
      coordinates : extent,
      fill : false,
      outline : true,
      outlineColor : Cesium.Color.WHITE
    }
  });
  
  var building;
  for (building of city['buildings']){
    drawBuilding(viewer, building);
  }
  
  scene.camera.flyTo({destination : extent});
  viewer.render();
});