# hatchbox plugins

install and uninstall plugins that add commands

* [`hatchbox plugins:install`](#hatchbox-pluginsinstall)
* [`hatchbox plugins:uninstall`](#hatchbox-pluginsuninstall)

## hatchbox plugins:install

Install a plugin and load it on every run.

```
Usage: hatchbox plugins:install PLUGIN
```

PLUGIN is a gem name or a path to a Ruby file. A gem that isn't installed yet gets installed into the Ruby running hatchbox. It only goes in the plugins list in ~/.hatchbox once it loads and adds at least one command. hatchbox plugins:uninstall takes it back out.

Examples:

```
$ hatchbox plugins:install hatchbox-acme
Installing hatchbox-acme... done
hatchbox-acme adds acme:secrets and acme:sync

$ hatchbox plugins:install ./script/hatchbox_commands.rb
```

## hatchbox plugins:uninstall

Stop loading a plugin and uninstall its gem.

```
Usage: hatchbox plugins:uninstall PLUGIN
```

PLUGIN is a gem name or a path, the same way it went in with plugins:install. A gem plugin's gem gets uninstalled too, every version of it, unless another gem depends on it or hatchbox is running under Bundler. A file plugin's file is left where it is.

Examples:

```
$ hatchbox plugins:uninstall hatchbox-acme
Removing hatchbox-acme from ~/.hatchbox... done
Uninstalling the hatchbox-acme gem... done
```
