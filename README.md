# How to install OSM TILE Server on Ubuntu 20.04

Its description how to manually install, setup and configure all the necessary software to operate your own tile server. These step-by-step instructions were written for Ubuntu Linux 20.04 LTS (Focal Fossa).

## Hardware Requirements

It’s recommended to use a server with a clean fresh OS.

The required RAM and disk space depend on which country’s map you are going to use. For example,

- The Luxembourge map requires at least 8G RAM and 30GB disk space.

- The UK map requires at least 12G RAM and 100GB disk space.

- The whole planet map requires at least 32G RAM and 1TB SSD (Solid State Drive). It’s not viable to use a spinning hard disk for the whole planet map.

You will need more disk space if you are going to pre-render tiles to speed up map loading in the web browser, which is highly recommended. Check this [tile disk usage page](https://wiki.openstreetmap.org/wiki/Tile_disk_usage) to see how much disk space are required for pre-rendering tiles. For example, if you are going to pre-render tiles from zoom level 0 to zoom level 15 for the planet map, an extra 460 GB disk space is required.

Another thing to note is that importing large map data, like the whole planet, to PostgreSQL database takes a long time. Consider adding more RAM and especially using SSD instead of spinning hard disk to speed up the import process.

## Services description

It consists of 5 main components: mod_tile, renderd, mapnik, osm2pgsql and a postgresql/postgis database.

- Mod_tile is an apache module that serves cached tiles and decides which tiles need re-rendering - either because they are not yet cached or because they are outdated.
- Renderd provides a priority queueing system for different sorts of requests to manage and smooth out the load from rendering requests.
- Mapnik is the software library that does the actual rendering and is used by renderd.
- Osm2pgsql is used to import OSM data into a PostgreSQL/PostGIS database for rendering into maps and many other uses.
- PostGIS is an extension to the PostgreSQL object-relational database system which allows GIS (Geographic Information Systems) objects to be stored in the database.

_The diagram shows an approximate operating principle of server components_

![schema](https://github.com/dbelkovsky/bash_scipts/blob/main/Osm_server.png)
