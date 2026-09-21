# Destination Catalog

Orbital Cleanup Co. now contains **50 distinct destination biomes** and **59 authored sectors**. A destination is a reusable data-driven visual/gameplay identity; a sector is an authored contract layout inside that identity.

Every destination owns a unique project-authored SVG primary asset, its own palette, a horizon treatment and an environmental-field combination. Normal gameplay never branches on a destination ID.

## Original launch identities

| Destination | Identity |
| --- | --- |
| Earth Orbit | Earth, stable baseline, orbital traffic |
| Lunar Belt | Moon, gravity wells and safe corridors |
| Mars Freight Route | Mars, freight currents and heavy recovery |
| Blue Nebula | Blue giant/nebula, low visibility and interference |

## Expanded library

| # | Destination | Career gate | Visual family |
| ---: | --- | --- | --- |
| 5 | Mercury Terminator | junior_cleaner | rocky / dust |
| 6 | Venus Cloud Deck | junior_cleaner | cloud / nebula |
| 7 | Main Asteroid Belt | junior_cleaner | belt / rings |
| 8 | Ceres Orbit | junior_cleaner | rocky / orbit |
| 9 | Jupiter Cloud Tops | orbital_cleaner | gas / gas |
| 10 | Io Volcanic Orbit | orbital_cleaner | lava / solar |
| 11 | Europa Ice Orbit | orbital_cleaner | ice / ice |
| 12 | Ganymede Magnetosphere | orbital_cleaner | moon / orbit |
| 13 | Callisto Outer Orbit | orbital_cleaner | moon / orbit |
| 14 | Saturn Ring Plane | senior_cleaner | ringed / rings |
| 15 | Titan Haze Orbit | senior_cleaner | cloud / nebula |
| 16 | Enceladus Plume Orbit | senior_cleaner | ice / ice |
| 17 | Rhea Crater Orbit | senior_cleaner | moon / orbit |
| 18 | Iapetus Ridge Orbit | senior_cleaner | moon / dust |
| 19 | Uranus Polar Orbit | senior_cleaner | gas / gas |
| 20 | Titania Canyon Orbit | senior_cleaner | ice / ice |
| 21 | Oberon Shadow Orbit | senior_cleaner | moon / orbit |
| 22 | Neptune Storm Orbit | sector_specialist | gas / gas |
| 23 | Triton Frost Orbit | sector_specialist | ice / ice |
| 24 | Pluto Heart Orbit | sector_specialist | dwarf / orbit |
| 25 | Charon Binary Orbit | sector_specialist | binary planet / orbit |
| 26 | Kuiper Belt Drift | sector_specialist | belt / rings |
| 27 | Eris Deep Orbit | sector_specialist | dwarf / ice |
| 28 | Haumea Fast Orbit | sector_specialist | dwarf / orbit |
| 29 | Makemake Red Orbit | sector_specialist | dwarf / dust |
| 30 | Solar Corona | sector_specialist | star / solar |
| 31 | Abandoned Orbital Station | sector_specialist | station / industrial |
| 32 | Deep-Space Ship Graveyard | sector_specialist | wreck field / industrial |
| 33 | Orbital Factory Ruins | sector_specialist | factory / industrial |
| 34 | Rogue Planet Night | sector_specialist | rogue planet / anomaly |
| 35 | Red Giant Perimeter | deep_space_operator | star / solar |
| 36 | White Dwarf Halo | deep_space_operator | star / solar |
| 37 | Pulsar Beam Zone | deep_space_operator | pulsar / anomaly |
| 38 | Neutron Star Magnetosphere | deep_space_operator | neutron star / anomaly |
| 39 | Black Hole Accretion Zone | deep_space_operator | black hole / anomaly |
| 40 | Binary Star Crossing | deep_space_operator | binary star / solar |
| 41 | Proxima Centauri Operations | deep_space_operator | star / solar |
| 42 | TRAPPIST-1 Inner System | deep_space_operator | multi-planet / orbit |
| 43 | Kepler-186f Orbit | deep_space_operator | exoplanet / orbit |
| 44 | Pelagic Exoplanet | deep_space_operator | ocean world / nebula |
| 45 | Magma Exoplanet | deep_space_operator | lava world / solar |
| 46 | Distant Ice Giant | deep_space_operator | ice giant / ice |
| 47 | Ringed Exoplanet | deep_space_operator | ringed world / rings |
| 48 | Crystal World | deep_space_operator | crystal / anomaly |
| 49 | Emerald Nebula | deep_space_operator | nebula / nebula |
| 50 | Supernova Remnant | deep_space_operator | supernova / anomaly |

## Architecture

- Primary artwork is editable SVG under `assets/original/planets/` for the original four and `assets/original/destinations/` for the expansion.
- Biome JSON owns `primary_asset`, scale, anchor, parallax, rotation, palette, horizon style and environmental fields.
- Sector JSON owns career order, deterministic seed, map scale, contract, modifiers, landmark selection and depot position.
- The generic Sector Engine remains responsible for generation. No destination-specific scene or destination-ID GDScript is required.
- Core QA loads every primary SVG and generates every authored sector.
- Browser QA samples major visual families instead of rendering fifty screenshots on every CI run.

## Content breadth

The 50 identities cover the terrestrial planets, the Sun, the asteroid belt, major Jovian and Saturnian moons, Uranian moons, the outer dwarf-planet region, abandoned human infrastructure, nearby stars, compact stellar objects, black-hole space, exoplanets, nebulae and a supernova remnant.
