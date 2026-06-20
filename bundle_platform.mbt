///|
fn BundlePlan::platform_files(self : BundlePlan) -> Array[BundleFile] {
  match self.target {
    MacOS =>
      [
        BundleFile::new(
          path="\{self.bundle_name}/Contents/Info.plist",
          content=self.info_plist(),
        ),
        BundleFile::new(
          path="\{self.bundle_name}/Contents/MacOS/\{self.executable_name}",
          content=macos_launcher(),
          executable=true,
        ),
      ]
    Windows =>
      [
        BundleFile::new(
          path="\{self.executable_name}/app.manifest.xml",
          content=self.windows_manifest(),
        ),
        BundleFile::new(
          path="\{self.executable_name}/\{self.bundle_name()}",
          content=windows_launcher(),
        ),
      ]
    Linux =>
      [
        BundleFile::new(
          path="\{self.executable_name}/\{self.executable_name}.desktop",
          content=self.desktop_entry(),
        ),
        BundleFile::new(
          path="\{self.executable_name}/\{self.executable_name}",
          content=linux_launcher(),
          executable=true,
        ),
      ]
  }
}

///|
fn BundlePlan::info_plist(self : BundlePlan) -> String {
  let identifier = self.identifier().xml_escape()
  let product = self.metadata.product_name().xml_escape()
  let version = self.metadata.version().xml_escape()
  let executable = self.executable_name.xml_escape()
  [
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
    "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" ",
    "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">",
    "<plist version=\"1.0\"><dict>",
    "<key>CFBundleIdentifier</key><string>\{identifier}</string>",
    "<key>CFBundleName</key><string>\{product}</string>",
    "<key>CFBundleDisplayName</key><string>\{product}</string>",
    "<key>CFBundleExecutable</key><string>\{executable}</string>",
    "<key>CFBundleShortVersionString</key><string>\{version}</string>",
    "<key>CFBundleVersion</key><string>\{version}</string>",
    if self.icon_path is Some(_) {
      "<key>CFBundleIconFile</key><string>AppIcon</string>"
    } else {
      ""
    },
    "</dict></plist>\n",
  ].join("")
}

///|
fn BundlePlan::windows_manifest(self : BundlePlan) -> String {
  let identifier = self.identifier().xml_escape()
  let product = self.metadata.product_name().xml_escape()
  [
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>",
    "<assembly xmlns=\"urn:schemas-microsoft-com:asm.v1\" manifestVersion=\"1.0\">",
    "<assemblyIdentity version=\"1.0.0.0\" processorArchitecture=\"*\" ",
    "name=\"\{identifier}\" type=\"win32\"/>",
    "<description>\{product}</description>",
    "</assembly>\n",
  ].join("")
}

///|
fn BundlePlan::desktop_entry(self : BundlePlan) -> String {
  [
    "[Desktop Entry]",
    "Type=Application",
    "Name=\{self.metadata.product_name()}",
    "Exec=\{self.executable_name}",
    "Icon=\{self.executable_name}",
    "Categories=Utility;",
    "",
  ].join("\n")
}

///|
fn macos_launcher() -> String {
  (
    #|#!/bin/sh
    #|APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
    #|exec lepusa-runtime launch --manifest "$APP_DIR/Resources/lepusa/runtime.json" "$@"
    #|
  )
}

///|
fn windows_launcher() -> String {
  (
    #|@echo off
    #|set "APP_DIR=%~dp0"
    #|lepusa-runtime.exe launch --manifest "%APP_DIR%lepusa\runtime.json" %*
    #|
  )
}

///|
fn linux_launcher() -> String {
  (
    #|#!/bin/sh
    #|APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
    #|exec lepusa-runtime launch --manifest "$APP_DIR/lepusa/runtime.json" "$@"
    #|
  )
}

///|
fn String::xml_escape(self : String) -> String {
  self
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&apos;")
}
