# EyeLayerWidth Example Data

The four MATs are geometry-only copies of the RpEGEN JoVE example groups:

| Group | Independent eyes |
| --- | ---: |
| DMSO_4dpi | 11 |
| IWR1_4dpi | 12 |
| DMSO_9dpf | 11 |
| IWR1_9dpf | 10 |

Images, sample names, polygon coordinates, masks, and centerline x/y/distance/angle
columns are unchanged. Intensity pixel arrays and intensity summaries are omitted.
These data test software behavior; they are not photoreceptor data or evidence
of biological validation for another layer.
See `SOURCE_MANIFEST.json` for source and derived-file SHA-256 identities.

## Input Format

One treatment group per MAT, stored as exactly one scalar struct with:

| Field | Required contents |
| --- | --- |
| IMG | Cell array of nonempty 2-D uint8 grayscale images |
| IMGname | Unique, nonempty image names, one per eye |
| ROIxy | One numeric N-by-2 finite polygon array per eye, in image x/y coordinates |
| CLine | One table per eye with finite numeric x, y, distance, and angle columns |
| ROIBW | Optional cell array of masks matching image dimensions; reconstructed from ROIxy if absent |

All cell arrays must have the same number of eyes. Centerline points must have
unique path ordering, lie inside image bounds, and use angles from 0 to 180
degrees. Polygons must describe one connected region without holes and agree
with their masks. Detailed geometry checks occur during measurement.

Full compatible RpEGEN group MATs also work; additional fields are ignored.
Permutation exports, width exports, and `_run.mat` metadata files are not geometry
inputs. Input files are read-only during analysis. Geometry is loaded directly;
no intensity analysis or additional application is required.

Source dataset: Leach, Fisher, and Gross (2022), JoVE,
[DOI 10.3791/63658](https://doi.org/10.3791/63658), distributed with RpEGEN.
