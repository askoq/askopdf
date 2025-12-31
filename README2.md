# AskoPDF Groups User Guide

This documentation contains instructions on setting up and managing page groups in the AskoPDF application. The implementation of this functionality aims to systematize document structure and optimize the user interface.

---

## 1. How to Start Creating a Group

To form a new group, perform the following actions:
* Click the navigation menu button on the top control panel.
* In the navigation panel that opens, find the **Groups** section.
* Click the **"+"** symbol located next to the section title to enter the configuration interface.

## 2. Configuring Basic Parameters (General Tab)

In the "Create Group" window, on the **General** tab, the following settings are available:
* **Group Name**: Enter a name in the corresponding field. If no input is provided, the system will assign a default name - "Unnamed Group".
* **Identifier (Icon)**: Select a symbol (emoji) for visual identification of the group in the list.

![Create group](https://files.catbox.moe/pscxj8.gif)

## 3. Visualization and Style Settings (Appearance Tab)

The **Appearance** tab is designed for customizing the interface color scheme:
* **Coloring Type**: Select **Solid** (single color) or **Gradient** mode.
* **Color Palette**: When selecting a gradient, you must define the Primary and Secondary colors.
* **Navigation Panel Color**: Set the color for the navigation menu and the current page indicator (Page Indicator), which will be active when working within this group.

![Appearance](https://files.catbox.moe/bef0u8.gif)

## 4. Creating the Page List (Pages Tab)

To include content in the group, switch to the **Pages** tab:
* **Adding Pages**: Enter page numbers in the corresponding field. The system supports both single entry (**Add** button) and adding ranges (e.g., entering "3-6" will add pages 3 through 6 inclusive).
* **Editing Data**: Each page in the list can be renamed by the user. These names will be displayed in the navigation menu instead of standard numbering.
* **Sorting**: It is possible to change the order of pages within the group.
* **Completion**: Click the **Create Group** button to save settings.

![Pages](https://files.catbox.moe/frx5yw.gif)

## 5. Managing Created Objects

* **Activation**: When a group is selected in the navigation menu, the interface color scheme and icons automatically adapt to the specified parameters.
* **Editing and Deletion**: To make changes or delete a group, use the "pencil" or "trash can" icons located next to the group name in the list.

---

> ### **Note**
> The architecture of the "Groups" function is based on linking to the name and file path of the source file. 
> * When moving or deleting a file, group data is saved in the application's local memory. 
> * When replacing a file with a version having an identical name and file path, previously created groups will be automatically applied to the current document.
