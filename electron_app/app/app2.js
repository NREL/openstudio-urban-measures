
// Use new ES6 modules syntax for everything.
import os from 'os'; // native node.js module
import { remote } from 'electron'; // native electron module
import jetpack from 'fs-jetpack'; // module loaded from npm
import { greet } from './hello_world/hello_world'; // code authored by you in this project
import env from './env';

console.log('Hello');

var app = remote.app;
var appDir = jetpack.cwd(app.getAppPath());
var city = appDir.read('city.json', 'json');
var map;

/** @this {google.maps.Polygon} */
function showArrays(event) {
  
  console.log(this);
  
  // Since this polygon has only one path, we can call getPath() to return the
  // MVCArray of LatLngs.
  var vertices = this.getPath();

  var contentString = '<b>Bermuda Triangle polygon</b><br>' +
      'Clicked location: <br>' + event.latLng.lat() + ',' + event.latLng.lng() +
      '<br>';

  // Iterate over the vertices.
  for (var i =0; i < vertices.getLength(); i++) {
    var xy = vertices.getAt(i);
    contentString += '<br>' + 'Coordinate ' + i + ':<br>' + xy.lat() + ',' +
        xy.lng();
  }

  var infoWindow = new google.maps.InfoWindow;
  
  // Replace the info window's content and position.
  infoWindow.setContent(contentString);
  infoWindow.setPosition(event.latLng);

  infoWindow.open(map);
}



function polygonCoordinates(polygon){
  var outer_points = [];
  var holes = [];

  for (let point of polygon['points']){
    outer_points.push([point['x'], point['y']]);
  }
  
  var result = [];
  result.push(outer_points);

  return result;
}

function drawBuilding(map, building) {
 
  var height = building['roof_elevation'] - building['surface_elevation'];
  var coordinates;
  
  for (let polygon of building['footprint']['polygons']){
    if (polygon['coordinate_system'] == "WGS 84"){
      coordinates = polygonCoordinates(polygon, height);
    }
  }
  
  var geoJSON = {"type": "FeatureCollection",
                 "features": [{
                   "type": "Feature",
                   "properties": {
                      "height": height,
                      "name": building['name'],
                      "building": building
                    },
                    "geometry": {
                      "type": "Polygon",
                      "coordinates": coordinates
                    }
                 }]
                };
  map.data.addGeoJson(geoJSON);
 
};
                
     
document.addEventListener('DOMContentLoaded', function() {
  
  console.log('DOMContentLoaded Started');
  
  var lng = city['region']['wgs_84_centroid']['x'];
  var lat = city['region']['wgs_84_centroid']['y'];
  
  map = new google.maps.Map(document.getElementById('googleMap'), {
    center: {lat: lat, lng: lng},
    zoom: 18,
    mapTypeId: google.maps.MapTypeId.HYBRID
  });
  
  var region_points = city['region']['polygon']['points'];
  var bounds = {
    west: region_points[0]['x'],
    south: region_points[0]['y'],
    east: region_points[2]['x'],
    north: region_points[2]['y']
  }
  map.fitBounds(bounds);
/*
  var drawingManager = new google.maps.drawing.DrawingManager({
    drawingMode: google.maps.drawing.OverlayType.MARKER,
    drawingControl: true,
    drawingControlOptions: {
      position: google.maps.ControlPosition.TOP_CENTER,
      drawingModes: [
        //google.maps.drawing.OverlayType.MARKER,
        //google.maps.drawing.OverlayType.CIRCLE,
        google.maps.drawing.OverlayType.POLYGON
        //google.maps.drawing.OverlayType.POLYLINE,
        //google.maps.drawing.OverlayType.RECTANGLE
      ]
    },
    //markerOptions: {icon: 'images/beachflag.png'},
    circleOptions: {
      fillColor: '#ffff00',
      fillOpacity: 1,
      strokeWeight: 5,
      clickable: false,
      editable: true,
      zIndex: 1
    }
  });
  drawingManager.setMap(map);
  */
  var building;
  for (building of city['buildings']){
    drawBuilding(map, building);
  }
  map.data.setStyle({
    fillColor: 'green',
    fillOpacity: 0.3,
    strokeWeight: 3
  });
  map.data.addListener('mouseover', function(event) {
    console.log(event.feature.getProperty('building'));
  });
  console.log('DOMContentLoaded Completed');
});

module.exports.city = city;