// Here is the starting point for your application code.
// All stuff below is just to show you how it works. You can delete all of it.

// Use new ES6 modules syntax for everything.
import os from 'os'; // native node.js module
import { remote } from 'electron'; // native electron module
import jetpack from 'fs-jetpack'; // module loaded from npm
import d3 from 'd3'; // module loaded from npm
import env from './env';

//console.log('Loaded environment variables:', env);

var app = remote.app;
var appDir = jetpack.cwd(app.getAppPath());
var baseline = appDir.read('baseline.geojson', 'json');
var proposed = appDir.read('proposed.geojson', 'json');
var allProperties = {};

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

  //var imageryProvider = new Cesium.BingMapsImageryProvider({
  //        url : "http://dev.virtualearth.net/",
  //        //tileProtocol: "http",
  //        tileDiscardPolicy: new Cesium.NeverTileDiscardPolicy(),
  //        errorEvent: imageryErrorEvent,
  //        //proxy : new Cesium.DefaultProxy('/proxy/'),
  //        key: bingKey
  //    });
      
  //var imageryProvider = new Cesium.ArcGisMapServerImageryProvider({
  //  url: 'http://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer'
  //});
  
  //var imageryProvider = new Cesium.OpenStreetMapImageryProvider({
  //        url : "http://a.tile.openstreetmap.org/"
  //    });

  var imageryProvider = Cesium.createOpenStreetMapImageryProvider({
          url : "http://a.tile.openstreetmap.org/"
      });
      
  var viewer;
  try {
    viewer = new Cesium.Viewer('cesiumContainer', {            
            imageryProvider : imageryProvider,
            baseLayerPicker : true,
            scene3DOnly : false,
            sceneModePicker: true,
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
  
  var bounds = d3.geo.bounds(baseline);

  var ellipsoid = Cesium.Ellipsoid.WGS84;
  var west = Cesium.Math.toRadians(bounds[0][0]);
  var south = Cesium.Math.toRadians(bounds[0][1]);
  var east = Cesium.Math.toRadians(bounds[1][0]);
  var north = Cesium.Math.toRadians(bounds[1][1]);

  var extent = new Cesium.Rectangle(west, south, east, north);
  
  //scene.mode = Cesium.SceneMode.SCENE2D;
  scene.mode = Cesium.SceneMode.SCENE3D;
  
  // Show the rectangle.  Not required; just for show.
  viewer.entities.add({
    rectangle : {
      coordinates : extent,
      fill : false,
      outline : true,
      outlineColor : Cesium.Color.WHITE
    }
  });
  
  var baseline_datasource = new Cesium.GeoJsonDataSource();
  viewer.dataSources.add(baseline_datasource);
  
  baseline_datasource.load(baseline, {
    stroke: Cesium.Color.BLACK,
    fill: Cesium.Color.WHITE,
    strokeWidth: 3,
    markerSymbol: '?'
  }).then( function() {
    var values = baseline_datasource.entities.values;
    for (var i = 0; i < values.length; i++) {
      var value = values[i];
      
      var surface_elevation = value.properties["surface_elevation"];
      var roof_elevation = value.properties["roof_elevation"];
      var height = roof_elevation - surface_elevation;
      
      //var average_roof_height = value.properties["average_roof_height"];
      values[i].polygon.extrudedHeight = height;
      
      for (let propertyName of Object.getOwnPropertyNames(value.properties) ){
        if (propertyName == "datapoint"){
          continue;
        }
        if (propertyName == "properties"){
          continue;
        }        
        if (!allProperties[propertyName]){
          allProperties[propertyName] = [];
        }
        allProperties[propertyName].push(value.properties[propertyName]);
      }
      if (value.properties["datapoint"] && value.properties["datapoint"]["results"]){
        var results = value.properties["datapoint"]["results"];
        for (let propertyName of Object.getOwnPropertyNames(results) ){
          if (!allProperties[propertyName]){
            allProperties[propertyName] = [];
          }
          allProperties[propertyName].push(results[propertyName]);
        }
      }
    } 

    var renderProperty = "total_site_eui";
    //var renderProperty = "floor_area";
    
    var allValues = allProperties[renderProperty].sort(function(a, b){return a-b});
    var domain = [allValues[0], allValues[allValues.length-1]];
    console.log(domain);
    var color_scale = d3.scale.linear().domain(domain).range(['blue', 'red']);
    
    for (var i = 0; i < values.length; i++) {
      var value = values[i];
      
      var x = value.properties[renderProperty];
      if (!x){
        if (value.properties["datapoint"] && value.properties["datapoint"]["results"]){
          x = value.properties["datapoint"]["results"][renderProperty];
        }
      }
      if (x){
        var y = color_scale(x);
        var c = Cesium.Color.fromCssColorString(y);
        values[i].polygon.material = c;
        values[i].polygon.outlineColor = Cesium.Color.BLACK;
      }else{
        console.log("No data");
      }
    } 
  })
  
  
  
  //viewer.dataSources.add(Cesium.GeoJsonDataSource.load(taxlots, {
  //  stroke: Cesium.Color.GREEN,
  //  fill: Cesium.Color.GREEN,
  //  strokeWidth: 3,
  //  markerSymbol: '?'
  //}));

  //var building;
  //for (feature of city['features']){
  //  drawBuilding(viewer, building);
  //}
  
  scene.camera.flyTo({destination : extent});
  viewer.render();
});