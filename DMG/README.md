# Creating DMG file

1. Archive your project. Use **Product > Archive** in Xcode.
2. Open Organizer, select Unsplash Wallpaper and latest build in the list. Then press "Export"
3. Choose "Export a Developer ID-signed Application" if you signed to Apple Developer program. Otherwise choose "Export as Mac Application".
4. Press "Next" and choose folder, where **.app** file will be saved.
5. Put **.app** file into **DMG** folder
6. Run in terminal:

`appdmg manifest.json UnsplashWallpaper.dmg`

**Note:** If you don't have installed **appdmg**, you can get it here: [https://github.com/LinusU/node-appdmg](https://github.com/LinusU/node-appdmg)