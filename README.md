# Calcium Imaging Analysis with sCaSpA

This repository contains example data and instructions for analyzing spontaneous calcium activity in neuronal cultures using **sCaSpA** (Spontaneous Calcium Spikes Analysis), a MATLAB-based graphical tool. The guide is written for beginners with no prior experience in calcium imaging analysis.

## What this project does

Calcium imaging records neuronal activity by measuring changes in fluorescence intensity over time. When a neuron fires, calcium ions flood into the cell, causing a calcium-sensitive dye (such as Fluo-4) to glow brighter. By recording a video of this fluorescence, we can track which neurons are active, how often they fire, and whether the network of neurons is acting in a coordainated (synchronous) way.

**sCaSpA** automates the key steps of this analysis: identifying neurons in the image, extracting their fluorescence traces over time, detecting calcium transients (spikes), and quantifying network-level activity patterns such as burst frequency and synchrony.

---

## 1. Install MATLAB

Download and install MATLAB from the [MathWorks website](https://www.mathworks.com/products/matlab.html). If you are a university student, your institution likely provides a free license — check your university's software portal.

MATLAB version **R2022b or later** is recommended.

---

## 2. Download this repository

You need a local copy of this repository on your computer. There are two ways to do this:

**Option A — If you know how to use Git:**

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
```

**Option B — If you don't use Git:**

1. On this GitHub page, click the green **"<> Code"** button near the top right.
2. Select **"Download ZIP"**.
3. Save the `.zip` file to a location you can easily find (for example, your `Documents` folder).
4. Unzip the folder by double-clicking it (macOS) or right-clicking → "Extract All" (Windows).

You should now have a folder containing all the project files, including the example data and the sCaSpA tool.

---

## 3. Install the required MATLAB Add-Ons

sCaSpA depends on several MATLAB toolboxes that may not be installed by default. You need to install the following Add-Ons:

- **Image Processing Toolbox** — required for reading and manipulating image files (`.tif` stacks)
- **Curve Fitting Toolbox** — required for fitting exponential decay curves to calcium transients during the Quantify step
- **Signal Processing Toolbox** — used for filtering and detrending fluorescence traces
- **Statistics and Machine Learning Toolbox** — used for threshold calculations and Gaussian mixture models

To install each one:

1. Open MATLAB.
2. Go to the **Home** tab in the toolbar.
3. Click **Add-Ons** → **Get Add-Ons**.
4. In the search bar, type the name of the toolbox (e.g., "Image Processing Toolbox").
5. Click on the toolbox in the search results and press **Install**.
6. MATLAB may restart after each installation — this is normal.

> **Note:** If MATLAB crashes during an Add-On installation, close MATLAB completely, reopen it, and try installing the Add-On again. The crash does not damage your installation.

---

## 4. Add the repository folder to the MATLAB path

MATLAB needs to know where the project files are located so it can access them. You do this by adding the downloaded folder to MATLAB's **path**:

1. Open MATLAB.
2. Go to the **Home** tab.
3. Click **Set Path** (in the Environment section of the toolbar).
4. In the dialog that opens, click **Add with Subfolders**.
5. Navigate to and select the folder you downloaded in Step 2 (the unzipped repository folder).
6. Click **Save**, then **Close**.

This tells MATLAB to look inside this folder (and all its subfolders) whenever it needs to find a function or a file. You only need to do this once — the path setting is saved for future sessions.

---

## 5. About the example data

**THE DATA CAN BE DOWNLOADED HERE: **https://drive.google.com/drive/folders/14Bh17yhraN6YkT2-Q2wruPix_C3kkkQF?usp=sharing

This repository includes a folder called **`Ca_data_test_1`** that contains example calcium imaging data ready to use. You do not need to open or modify any files inside this folder manually — when you launch sCaSpA and click **Open data**, you will point it to this folder and the software will load everything automatically.

The example data was recorded from a primary cortical neuronal culture loaded with the calcium-sensitive dye Fluo-4, imaged with a widefield epifluorescence microscope at **8 frames per second** (8 Hz).

---

## 6. Understanding the files inside `Ca_data_test_1`

The folder contains exactly two files:

### 6.1. `240711_rai235_i10_w6_DIC_Well00_Time00.tif`

This is the **still reference image** (a single-frame photograph). "DIC" stands for Differential Interference Contrast — a microscopy technique that reveals cell morphology (shape) without fluorescence. This image is used as a spatial reference so you can see where the neurons are located and overlay your regions of interest (ROIs) on top of recognizable cell structures.

- **Type:** single-frame `.tif` image
- **Purpose:** visual reference for identifying and placing ROIs on cell bodies

### 6.2. `240711_rai235_i10_w6_Well00_Time00.tif`

This is the **calcium imaging movie** (a multi-frame `.tif` stack). Each frame is a snapshot of the fluorescence at one point in time. The full stack contains 960 frames recorded at 8 Hz, giving a total recording duration of 120 seconds (2 minutes). This is the actual data from which fluorescence traces, spike detection, and network metrics are extracted.

- **Type:** multi-frame `.tif` stack (960 frames)
- **Purpose:** the time-lapse recording of calcium activity that gets analyzed

### 6.3. What the filename structure means

sCaSpA requires a specific filename format to correctly identify and link the still image to its corresponding movie. The filenames are structured with underscores (`_`) separating meaningful tokens:

```
240711_rai235_i10_w6_DIC_Well00_Time00.tif
  │      │     │    │   │     │       │
  │      │     │    │   │     │       └── timepoint identifier
  │      │     │    │   │     └────────── well/coverslip ID (must contain "Well" or "cs")
  │      │     │    │   └──────────────── still-image keyword (must match the "Still Condition" field in sCaSpA)
  │      │     │    └──────────────────── week identifier
  │      │     └───────────────────────── experiment identifier
  │      └─────────────────────────────── culture/sample identifier
  └────────────────────────────────────── date (YYMMDD format: July 11, 2024)
```

sCaSpA identifies which file is the still image by searching for the text you enter in the **Still Condition** field (in this case, `DIC`). The file containing `DIC` in its name is treated as the reference image; the file without it is treated as the movie.

Both files are linked together through the shared `Well00` token — this is how sCaSpA knows they belong to the same field of view.

> **About the "name mismatch" warning:** When loading this data, sCaSpA may display a warning dialog that says *"name mismatch, but I don't know what to do"*. This happens because the filename contains more underscore-separated tokens than the software's parser was originally designed for. **This warning is harmless** — click OK and proceed. The data loads correctly despite the warning.

---

## 7. Checking and matching image dimensions (pixel resolution)

Before loading data into sCaSpA, it is important to verify that the still image and the movie have **the same pixel dimensions** (width × height in pixels). If they don't match, the ROIs you place on one image will appear in the wrong location on the other, because the coordinate systems won't align.

This mismatch can happen when the still image is captured at full camera resolution but the movie is recorded with **pixel binning** (a common technique where the camera groups adjacent pixels together to increase brightness and recording speed, at the cost of spatial resolution). For example, 2×2 binning produces an image that is half the width and half the height of the unbinned original.

### 7.1. How to check the dimensions

In MATLAB's Command Window, run the following commands (adjust the filenames to match your own data):

```matlab
dicInfo = imfinfo('240711_rai235_i10_w6_DIC_Well00_Time00.tif');
movInfo = imfinfo('240711_rai235_i10_w6_Well00_Time00.tif');

fprintf('Still image (DIC):  %d x %d pixels\n', dicInfo(1).Width, dicInfo(1).Height)
fprintf('Movie:              %d x %d pixels\n', movInfo(1).Width, movInfo(1).Height)
```

### 7.2. Example of a dimension mismatch

If the still image was taken without binning and the movie was recorded with 2×2 binning, you would see something like:

```
Still image (DIC):  1412 x 1412 pixels
Movie:              706 x 706 pixels
```

This means the DIC image has **4× as many pixels** as the movie (twice the width × twice the height). If you load these into sCaSpA as-is, an ROI placed at pixel coordinate (400, 300) on the movie would appear at the same numerical position on the DIC image — but since (400, 300) represents a completely different physical location in a 1412-pixel-wide image than in a 706-pixel-wide image, the overlay would be misaligned.

### 7.3. Which file to resize

Always resize the **still image (DIC)** to match the movie, not the other way around. The movie contains the actual scientific data across many frames — resizing it would alter the fluorescence values and potentially introduce artifacts. The DIC image is only used as a visual reference, so downscaling it is safe and does not affect any analysis.

### 7.4. How to resize the still image

Before resizing, it is good practice to **make a backup copy** of the original file so you don't lose the full-resolution version:

```matlab
copyfile('240711_rai235_i10_w6_DIC_Well00_Time00.tif', ...
         '240711_rai235_i10_w6_DIC_Well00_Time00_FULLRES.tif')
```

Then resize the DIC image to match the movie's dimensions:

```matlab
dicImg = imread('240711_rai235_i10_w6_DIC_Well00_Time00.tif');
dicSmall = imresize(dicImg, [706 706]);
imwrite(dicSmall, '240711_rai235_i10_w6_DIC_Well00_Time00.tif');
```

This overwrites the DIC file with a 706 × 706 version. You can verify the result by running the dimension check from Step 7.1 again — both files should now report the same dimensions.

> **Important:** After resizing, make sure only the two correctly named files remain in the data folder (`Ca_data_test_1`). If the backup copy (`_FULLRES.tif`) is in the same folder, sCaSpA may try to parse it and get confused. Move the backup to a different location.

### 7.5. About the provided example data

The example data included in this repository has **already been resized** so that both files share the same 706 × 706 pixel dimensions. You do not need to perform any resizing — this section is here so you know what to do when working with your own data.

---

## 8. Launching sCaSpA

Once all the steps above are completed, you are ready to launch the analysis tool. In MATLAB's Command Window, type:

```matlab
sCaSpA
```

This opens the sCaSpA graphical interface. Before loading any data, configure the following fields in the **Load Options** panel on the right side of the window:

| Field | Value | Why |
|---|---|---|
| **Still Condition** | `DIC` | Tells sCaSpA which filename token identifies the still image |
| **File format** | `tif` | The format of your image files |
| **Frequency** | `8` | The recording frame rate in Hz (frames per second) |

Then click **Open data** and navigate to the `Ca_data_test_1` folder. Both images should load: the DIC reference on the left panel and the first frame of the movie on the right.


---

## 9. Configuring sCaSpA for the example data

Once sCaSpA is open, you need to configure the settings in the right-side panel. Below is a description of every setting and the value to use for the example data provided in this repository.

### 9.1. Load Options

| Setting | Value | What it does |
|---|---|---|
| **Still Condition** | `DIC` | This tells sCaSpA how to distinguish the still reference image from the movie. The software scans all filenames in the folder and looks for the text you type here. Any file whose name contains `DIC` is treated as the still image; files without it are treated as movies. Since our still image is named `240711_rai235_i10_w6_DIC_Well00_Time00.tif`, we type `DIC` to match that keyword. |
| **File format** | `tif` | The file format of your image data. Our files are `.tif` (Tagged Image File Format), the standard format for microscopy images. The other option, `nd2`, is for Nikon microscope files. |
| **Frequency** | `8` | The imaging frame rate in Hz (frames per second). Our example data was recorded at 8 frames per second, meaning the camera took 8 photographs every second. This number is critical because it converts frame counts into real time — for example, 1 frame = 125 milliseconds at 8 Hz. You must set this to match the frame rate used during your actual recording. |

### 9.2. ROIs Options

| Setting | Value | What it does |
|---|---|---|
| **ROI Size (pxs)** | `15` | The radius (in pixels) of each region of interest. When you place an ROI on a cell, the software draws a shape extending 15 pixels outward from the center point you clicked. The total diameter of the captured area is therefore approximately 31 pixels across. This value should match the typical size of a neuronal soma in your image — if the cells appear larger or smaller, adjust accordingly. To measure the size of a soma, you can use MATLAB's `imtool` command (see the [Measuring soma size](#measuring-soma-size) section below). |
| **ROI Shape** | `Circle` | The geometric shape of each ROI. `Circle` is generally preferred over `Square` because neuronal cell bodies are roughly round, so a circular ROI captures the soma without including as many background pixels from the corners. |
| **ROIs #** | `20` | An approximate estimate of how many neurons you expect to find in the image. This number is only used by the automatic ROI detection algorithm (`Detect ROIs` button) to calibrate how strict or loose the detection threshold should be. If you are placing ROIs manually (which is recommended for this example), this value has no effect on your analysis. |

### 9.3. Detection Options

These settings control how calcium transients (spikes) are identified in the fluorescence traces. They are not used until the **Detect** step later in the pipeline, but it is good practice to set them now.

| Setting | Value | What it does |
|---|---|---|
| **Method** | `MAD` | The statistical method used to calculate the threshold that separates real calcium events from baseline noise. `MAD` stands for Mean Absolute Deviation — it computes the median of the trace (the resting baseline) and adds a multiple of the typical noise level on top. Other options include `Normalized MAD` (which rescales the noise to standard-deviation units for easier interpretation) and `Rolling St. Dev.` (which uses a moving baseline that tracks slow drift like photobleaching). For a first analysis, `MAD` is a reasonable starting point. |
| **Threshold** | `0.15` | The multiplier applied to the noise estimate. A higher value means stricter detection (fewer spikes accepted, lower false-positive rate); a lower value means looser detection (more spikes accepted, higher risk of noise being counted as a spike). The value `0.15` here is in ΔF/F₀ units, meaning only fluorescence changes greater than 15% above the computed baseline+noise level will be counted as spikes. |
| **Min Prominence** | `0.03` | The minimum amount a peak must stand out from its immediate surroundings to be counted as a spike. This prevents small wiggles on top of a larger slow rise from being detected as separate events. A value of `0.03` means the peak must rise at least 3% ΔF/F₀ above its neighboring valleys. |
| **Min Distance (frames)** | `1` | The minimum number of frames that must separate two consecutive detected spikes. At 8 Hz, 1 frame = 125 ms. This prevents the same calcium transient from being double-counted if its peak has a noisy shoulder. |
| **Min Duration (frames)** | `2` | The minimum width (in frames) a peak must have to be accepted. At 8 Hz, 2 frames = 250 ms. Peaks narrower than this are likely noise rather than real calcium transients, since a genuine Fluo-4 transient typically lasts several hundred milliseconds or longer. |
| **Max Duration (frames)** | `30` | The maximum width (in frames) a peak can have before it is rejected. At 8 Hz, 30 frames = 3.75 seconds. This prevents very long, slow changes (like photobleaching or drift) from being counted as a single giant spike. Real calcium transients in neuronal cultures rarely exceed a few seconds. |
| **Trace to use** | `Raw` | Which version of the fluorescence trace to search for peaks in. `Raw` uses the ΔF/F₀ trace as-is (after detrending). Other options include `Gradient` (the frame-to-frame rate of change, which is less affected by slow drift) and `Smooth` (a denoised version using wavelet filtering). `Raw` is the standard starting point. |

### 9.4. Registration Options

| Setting | Value | What it does |
|---|---|---|
| **Registration** | checked or unchecked | This checkbox was intended to enable motion correction (aligning frames to compensate for sample drift during recording). However, in the current version of sCaSpA (v1.3#3), this feature is not implemented — the checkbox is stored as a setting but does not trigger any computation. **It makes no difference whether this is checked or unchecked.** You can leave it in either state. |

### 9.5. Detrending Options

| Setting | Value | What it does |
|---|---|---|
| **Detrending Method** | `Mov Median` | The method used to remove slow baseline drift from the fluorescence traces before spike detection. `Mov Median` (Moving Median) slides a window across the trace, computes the median value within that window at each time point, and subtracts it from the original trace. This effectively removes slow changes like photobleaching (the gradual fading of fluorescence intensity over time) while preserving the fast, sharp calcium transients. The median is used rather than the mean because it is resistant to being pulled upward by spike values that happen to fall inside the window. |
| **Detrend Window (fr)** | `200` | The width of the sliding window, in frames. At 8 Hz, 200 frames = 25 seconds. This window should be substantially longer than the longest calcium transient you expect (set by Max Duration = 30 frames = 3.75 seconds) so that the moving median does not accidentally "follow" a transient and subtract it out. At the same time, it should be shorter than the total recording length (960 frames = 120 seconds) so that it can track baseline drift within the recording. A value of 200 frames provides a good balance for this example data. |

After configuring all these settings, click **Open data** and navigate to the `Ca_data_test_1` folder. Both images should load into the interface.

> **Note:** If you see a warning dialog saying *"name mismatch, but I don't know what to do"*, click OK and proceed — this is harmless (see [Troubleshooting](#troubleshooting)).

---

## 10. Viewing the standard deviation projection

Before identifying neurons, you need a way to see **which cells are actually active** in the recording — not just which cells happen to be visible in a single frame.

Click the **Show StDev** button at the top of the interface (next to "Show Frame" and "Show Movie").

This computes the **standard deviation of every pixel across all frames** of the movie. For each pixel location, the software looks at how much that pixel's brightness fluctuated over the entire 960-frame recording:

- **Pixels on active neurons** flicker brighter and dimmer as calcium rises and falls with each spike → high standard deviation → appear **bright** in the projection.
- **Pixels on background or inactive cells** stay at roughly constant brightness throughout → low standard deviation → appear **dark** in the projection.

The result is a single image (displayed on the **right panel** in a red/orange color map) that highlights the spatial footprint of activity across the full recording. Bright, round blobs in this image are your best candidates for active neuronal cell bodies.

> **Note:** The standard deviation projection is computed from whichever movie is currently selected in the **Timelapse_ID dropdown** at the top of the interface. If you have multiple recordings loaded, make sure the correct one is selected before clicking Show StDev.

---

## 11. Selecting regions of interest (ROIs)

ROIs define which cells you want to analyze. Each ROI is a small circular area centered on a neuronal cell body; the software will extract the average fluorescence intensity within that circle at every frame to build a time-series trace for that neuron.

### 11.1. Why use the right (StDev) image for ROI placement

You can click on **either panel** to place ROIs — both the left (DIC/still) and right (StDev) panels respond to clicks and record the same pixel coordinates. However, placing ROIs using the **right panel (StDev image) is strongly recommended** because:

- The StDev image shows you **which cells were active** during the recording, not just which cells are present. A cell that is visible in the DIC image might be dead or silent — placing an ROI on it would produce a flat, uninformative trace.
- The bright blobs in the StDev image directly correspond to the **spatial footprint of calcium activity**, so you know the ROI is capturing a region that actually fluctuated over time.
- Some cells that are hard to see in a single DIC frame (due to low contrast or being slightly out of focus) may still appear clearly in the StDev projection if they were active.

### 11.2. How to place ROIs manually

1. Click the **Add ROIs** button at the top of the interface. The button will appear pressed/highlighted, and your cursor will change to a crosshair.
2. Click on each bright blob (active neuron) in the **right panel** (StDev image). Each click places one ROI. A colored circle will appear at the position you clicked.
3. Repeat for every neuron you want to include in your analysis. You can place as many ROIs as you want.
4. When you are finished, click the **Add ROIs** button again to deactivate placement mode. The software will display a loading message (e.g., "Loading 22 ROIs") as it extracts the fluorescence trace for each ROI across all 960 frames.
5. After loading completes, the ROI circles will also appear on the **left panel** (DIC image) at the corresponding positions, and the **Ca²⁺ Trace** plot at the bottom will populate with the extracted traces.

> **Important — ROI size and shape:** The size and shape of each ROI circle are determined by the values you set in the **ROIs Options** panel (`ROI Size = 15`, `ROI Shape = Circle`). All ROIs share the same size and shape — you cannot adjust these per-cell. If your cells vary significantly in size, set the ROI size to match the **average** soma diameter rather than the largest or smallest.

> **Important — Image dimensions must match:** The ROI circles should appear at the **same physical position** on both panels. If they appear shifted or clustered toward one side of the left panel, this means the still image and the movie have different pixel dimensions (see [Section 7](#7-checking-and-matching-image-dimensions-pixel-resolution) for how to fix this). For the provided example data, the dimensions are already matched, so this should not be an issue.

### 11.3. Removing incorrect ROIs

If you accidentally place an ROI in the wrong location:

1. Click the **Delete ROIs** button.
2. Click on the incorrectly placed ROI circle (on either panel) to remove it.
3. Click **Delete ROIs** again to deactivate deletion mode.

---

## 12. Spike Detection

After placing your ROIs, the next step is to detect the calcium transient peaks (spikes) in each fluorescence trace. This is done using the **Spike Detection** panel.

### 12.1. Selecting which data to detect spikes on

Before clicking **Detect**, you need to decide which traces to run detection on:

| Button | What it does | When to use it |
|---|---|---|
| **All FOVs** | Runs spike detection on every field of view (every recording) loaded in the current session. | Use this when you have loaded multiple movies and want to process all of them in one step. |
| **Selected FOV** | Runs spike detection only on the recording currently selected in the `Timelapse_ID` dropdown. | Use this when you have multiple recordings but only want to test or process one at a time. |
| **Current List** | Runs detection on the subset of FOVs belonging to the currently selected experiment. | Useful for batch processing specific experimental groups after filtering your data. |
| **Selected Trace** | Runs detection only on the single ROI (cell) currently highlighted in the Ca²⁺ Trace plot. | Use this to re-run detection with different threshold settings on a specific problem cell, without overwriting the results for all other cells. |

For this example, with only one recording loaded, click **All FOVs** to be explicit, then click **Detect**.

### 12.2. How detection works and the critical settings

The algorithm identifies spikes by measuring how far a peak rises above the resting noise level. The behavior of this algorithm is heavily controlled by the **Detection Options** panel. 

**Key Method Options:**
*   **MAD (Mean Absolute Deviation):** Computes the median baseline of the trace and sets the threshold by adding the absolute deviation multiplied by your **Threshold** value. Best for clean, stable baselines.
*   **Normalized MAD:** A statistically robust version of MAD scaled to approximate the standard deviation (using a specific inverse error function modifier). Best for datasets with frequent, densely packed spikes where traditional standard deviation is artificially inflated.
*   **Rolling St. Dev.:** Uses a sliding window (sized based on your Max Duration + Min Distance settings) to calculate a local moving mean and standard deviation. Best for recordings with significant baseline drift or photobleaching that detrending did not fully remove.

**Running the steps:**
*   **Detect** identifies the location (time point) and amplitude of each calcium transient peak based on your Threshold and Duration settings. It marks detected events as vertical light-blue stripes in the Ca²⁺ Trace plot.
*   **Quantify** must always be run *after* Detect. It uses the peak locations to compute complex kinetics (rise/decay times) and network synchrony. 

### 12.3. Manually correcting detections: Add Peak and Remove Peak

If the algorithm misses a spike or flags a noise artifact, you can manually correct it in **Single Trace** mode:

*   **Add Peak:** Click the button, then left-click on the missed peak in the trace plot. The code searches a small local window around your click to snap exactly to the true local maximum. *Tip: Right-clicking while in this mode will undo the last manually added peak.*
*   **Remove Peak:** Click the button, then left-click near a falsely detected peak to delete it. The peak marker will turn into a red 'x' to indicate deletion. *Tip: Right-clicking in this mode undoes the last deletion.*

*Always click **Quantify** again after making manual edits to update the statistics.*

---

## 13. Quantification

Click **Quantify** (with **All FOVs** selected) after running Detect. This step builds the comprehensive statistics table.

### 13.1. How Quantify computes spike kinetics

For each detected spike, the algorithm does the following:
1.  **Onset Detection (Rise):** Walks backward from the peak until it finds the deepest valley before the previous spike.
2.  **Offset Detection (Decay):** Walks forward from the peak until it finds a valley that returns closest to the baseline intensity.
3.  **Spike Widths:** Calculates the duration of the spike at exactly 25%, 50%, 75%, and 90% of the peak's prominence (height above baseline).
4.  **Exponential Fit:** Uses the Curve Fitting Toolbox to fit a non-linear exponential curve (`exp1`) to the decay phase, extracting a highly accurate decay time constant (τ).

### 13.2. How Quantify computes network synchrony

Across all cells, the software calculates network bursting behavior:
*   **Network Raster Generation:** The code converts individual cell spikes into blocks of active time based on your chosen spike width (see `Network level` below). 
*   **Network Frequency:** It sums these active blocks across all cells, applies a Gaussian smoothing window, and detects "Network Peaks". A network peak is only counted if the number of participating cells exceeds the threshold defined by your **Network %** setting.

### 13.3. Options that activate after Quantify

After Quantify completes, new visualization toggles unlock in the bottom-right panel:
*   **Show Peaks:** Overlays red circles directly on the detected peaks in the trace plot.
*   **Show Rise/Decay (Single Trace only):** Colors the computed rising phase of the spike in **pink** and the decaying phase in **green**. This allows you to visually verify the onset/offset valleys calculated in step 13.1.
*   **Show as Raster:** Replaces the Y-axis fluorescence scale with cell IDs, displaying a timeline of dots representing firing events.

---

## 14. Understanding the Ca²⁺ Trace plot

The bottom panel displays the **Ca²⁺ Trace** plot, providing visual feedback of the signal and detections.

### 14.1. Axes
*   **X-axis (Time in seconds):** The full recording duration. Calculated automatically using your total frame count divided by the **Frequency** (Hz) setting.
*   **Y-axis (ΔF/F₀):** The normalized fluorescence change. A value of 0.3 means the cell is 30% brighter than its resting baseline level.

### 14.2. Visual Elements in "All And Mean" Mode
*   **Gray lines ("All"):** Individual ΔF/F₀ traces for every loaded ROI. 
*   **Red line ("Mean"):** The average of all active traces at every time point. Sharp upward deflections here strongly indicate synchronized network bursts.
*   **Light blue vertical stripes:** Mark the detection window (±0.1 seconds) around a spike peak. Because these patches are drawn with 10% opacity, they stack on top of each other. Denser, darker blue vertical bands instantly highlight moments of high network synchrony where many cells fired simultaneously.

### 14.3. Visual Elements in "Single Trace" Mode
When you switch to **Single Trace** and toggle **Show Rise/Decay**, the plot isolates one cell:
*   **Black line:** The specific cell's ΔF/F₀ trace.
*   **Blue dotted horizontal line:** The dynamic detection threshold calculated for this specific cell (e.g., the MAD threshold line).
*   **Red circles:** The peak maxima.
*   **Pink/Green segments:** The exact boundaries of the rising (pink) and decaying (green) phases measured by the quantification algorithm.

---

## 15. Plot Interaction panel

This panel controls the Trace Plot navigation.

| Control | What it does | Interaction Details |
|---|---|---|
| **Plot Type** | Toggles between **All And Mean** and **Single Trace** views. | Changing to Single Trace enables the `Cell Number`, `Add/Remove Peak`, and `Show Rise/Decay` controls. |
| **Zoom X** | Sets the start and end of the visible X-axis time window. | Type the exact start and end seconds in the two numeric boxes. |
| **Fix Y Axis** | Locks the Y-axis limits. | Prevents the plot from auto-scaling when you switch between cells with vastly different fluorescent amplitudes. |
| **Cell Number** | Steps through individual ROIs (`-` and `+`). | Only active in Single Trace mode. Adjusts the highlighted cell and trace. |
| **Show active** | Highlights the current ROI in the image panels above. | Helps you physically locate which cell in the culture corresponds to the trace you are inspecting. |

---

## 16. Other settings and interactions

This panel contains advanced thresholds that deeply impact how network synchrony is defined during quantification. 

### 16.1. Network & Synchronicity Thresholds
These settings determine how the software decides if two spikes from different cells "overlap" in time to form a network burst.

*   **Network level / Synch level:** These dropdowns (`Baseline`, `25%`, `50%`, `75%`, `90%`) control the "width" of a spike for overlap calculations. 
    *   *How it works:* If set to `50%`, the algorithm uses the spike's Full Width at Half Maximum (FWHM) as its active window. Two cells are only considered firing "synchronously" if their 50% width windows overlap. A stricter setting (e.g., `90%` near the peak) requires spikes to happen at almost the exact same millisecond.
*   **Network %:** Defines the minimum percentage of active cells required to declare a network burst. If set to `80`, then 80% of all firing cells must have overlapping spike windows (defined by the Network level) for the software to count it as a `NetworkFrequency` event.

### 16.2. Additional Toggles
*   **Label ROIs:** Allows you to click on ROIs to assign them to a sub-group. Doing this before Quantify calculates all metrics separately for the labeled (`...Positive`) vs unlabeled (`...Negative`) populations.
*   **Keep FOV / Keep Trace:** Green toggles that dictate whether a whole recording (FOV) or an individual cell (Trace) is included in the final data export. Click to reject noisy data.
*   **Load each FOV & Batch load movie:** Used for processing highly multiplexed experiments automatically.

---

## 17. Exporting the data

Click **Save** in the top panel to export your results, then choose **Analysis**. 

### 17.1. What NOT to select (Preventing CSV Crashes)
The underlying export function relies on MATLAB's `writetable`, which requires flat, 2D data. If you select variables containing raw matrices or arrays of variable lengths, MATLAB will forcefully flatten thousands of data points into a single row, breaking the CSV.

**Do not select these arrays:** `ImgByteStrip`, `RawIntensity`, `FF0Intensity`, `DetrendData`, `KeepROI`, `SpikeLocations`, `SpikeIntensities`, `SpikeWidths`, `SpikeProperties`, `SpikeRaster`, `FWHMRaster`, `NetworkRaster`, `SpikeInOut`, `CellFrequency`.

### 17.2. Safe Metadata Columns
Select these single-value identifiers to track your experiments:
`Filename`, `CellID`, `Week`, `CoverslipID`, `RecID`, `Condition`, `ExperimentID`, `KeepFOV`, `Fs`.

### 17.3. Core Calcium Metrics
Select these scalar values for your downstream statistical analysis. For every cell-level metric below, the software exports the **Mean, Median, Variance, Skewness, Kurtosis, CoV** (Coefficient of Variation), and **QCD** (Quantile Coefficient of Dispersion—a robust alternative to CoV that uses quartiles) across the whole network.

| Metric | Biological Interpretation |
|---|---|
| **NetworkFrequency** | The number of synchronized population bursts per minute. Plummets under pharmacological silencing (e.g., TTX). |
| **SilentCells** | The percentage of ROIs that did not fire a single spike. |
| **...Frequency** | Spikes per minute averaged across all active cells. |
| **...InterSpikeInterval** | Time between consecutive spikes. Short intervals with high variance indicate bursting behavior. |
| **...Synchronicity** | The average percentage of the network participating in a sync event. |
| **...Isolated** | The percentage of spikes that occurred independently, outside of network bursts. |
| **...TimeToRise / DecayTau** | Rise time and exponential decay tau characterize the calcium influx and dye unbinding kinetics. |
| **...Duration50** | The Full Width at Half Maximum (FWHM) of the spikes. Wider spikes indicate prolonged calcium clearance. |
| **...Prominence** | The peak amplitude above the local baseline noise, representing the strength of the calcium transient. |

*Note: If you utilized the "Label ROIs" tool, all of these statistics are additionally exported as `...Positive` and `...Negative` columns for direct sub-population comparisons.*

---
### Measuring soma size

To determine the correct ROI Size for your own data, you can measure the diameter of a neuron's cell body in pixels:

1. Compute the StDev projection from MATLAB's Command Window:

```matlab
info = imfinfo('YOUR_MOVIE_FILE.tif');
nFrames = numel(info);
stack = zeros(info(1).Height, info(1).Width, nFrames, 'uint16');
for f = 1:nFrames
    stack(:,:,f) = imread('YOUR_MOVIE_FILE.tif', f);
end
stdImg = std(double(stack), 0, 3);
imtool(stdImg, [min(stdImg(:)), max(stdImg(:))])
```

2. In the `imtool` window that opens, hover your cursor over the **left edge** of a bright soma and note the X coordinate displayed at the bottom of the window.
3. Hover over the **right edge** of the same soma and note the new X coordinate.
4. Subtract to get the diameter: `diameter = right_X - left_X`.
5. Divide by 2 to get the ROI Size value: `ROI_Size = diameter / 2`.
6. Repeat for 2–3 different cells and use the average.

For the example data in this repository, soma diameters measured approximately 35 pixels, giving an ROI Size of approximately 15–17.

---

## Troubleshooting

### sCaSpA window freezes after clicking Open data
This usually means a dialog box has appeared behind the main window. Press **Cmd+`** (Mac) or **Alt+Tab** (Windows) to cycle through MATLAB windows and find the hidden dialog. The most common cause is leaving the **Still Condition** field empty before loading.

### "name mismatch, but I don't know what to do" warning
This is harmless. Click OK. It occurs because the filenames have more underscore-separated tokens than sCaSpA's parser expects, but the data loads correctly regardless.

### "fittype requires Curve Fitting Toolbox" error during Quantify
The Curve Fitting Toolbox is not installed. Follow the instructions in Step 3 to install it via Add-Ons.

