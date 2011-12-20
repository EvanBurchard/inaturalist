if @place_geometry
  xml.Placemark do
    xml.name "#{@place.name} Border"
    xml.styleUrl "#{root_url}stylesheets/index.kml#place"
    xml << @place_geometry.geom.as_kml
  end
else
  xml.Placemark do
    xml.name @place.name
    xml.styleUrl "#{root_url}stylesheets/index.kml#place"
    xml.Point do
      xml.coordinates("#{@place.longitude},#{@place.latitude}")
    end
  end
end
