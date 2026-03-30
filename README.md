# Redmine Issue References Plugin

## Overview

Write an issue number in a Redmine Wiki page, and the issue can reverse-reference that Wiki page.

Introductory article (Japanese): [redmine_issue_references — a Redmine plugin (Zenn)](https://zenn.dev/articles/2852df0bd60ea4)

## Features

- When an issue number is written in a Wiki page, the corresponding issue can reference that Wiki entry in reverse
- References are automatically updated when the Wiki is edited
- Easily add referenced Wiki entries to the issue
- Show New/Updated badges for new or updated references
- Hide or restore unnecessary references
- Manage settings easily from the plugin settings screen
   - Badge display period(Day(s))
   - Context information to extract
   - Heading sections to extract
- Multilingual support (Japanese/English)

## Installation

1. Clone this repository into your Redmine plugins directory:

   ```bash
   cd {REDMINE_ROOT}/plugins
   git clone https://github.com/Mattani/redmine_issue_references.git
   ```

2. Run plugin migration:

   ```bash
   cd {REDMINE_ROOT}
   bundle exec rake redmine:plugins:migrate RAILS_ENV=production
   ```

3. Restart Redmine:

   ```bash
   sudo systemctl restart httpd
   ```

4. Open the settings page of the project you want to enable the plugin for, go to the **"Information" tab → "Modules" section**, check "Issue Reference", and save. The plugin will be activated for that project, and the "Issue Reference" tab will appear in the project settings.

## Uninstallation

1. Revert plugin migration:

   ```bash
   cd {REDMINE_ROOT}
   bundle exec rake redmine:plugins:migrate NAME=redmine_issue_references VERSION=0 RAILS_ENV=production
   ```

2. Remove the plugin directory:

   ```bash
   rm -rf {REDMINE_ROOT}/plugins/redmine_issue_references
   ```

3. Restart Redmine:

   ```bash
   sudo systemctl restart httpd
   ```

## Requirements

- Redmine 5.0.0 or higher

## License

GPL v3.0

## Author

H.Matsutani (C) 2026
