# HaxeQuake

## What is it?

**HaxeQuake** is [Haxe](http://haxe.org/) port of a [HTML5 WebGL port](https://github.com/SiPlus/WebQuake) of the game Quake by id Software.

Client is fully ported to Haxe and perfectly playable, you can try playing shareware Quake version right from this repository: [here](http://nadako.github.io/HaxeQuake/Client/WebQuake.htm). It was tested and probably only works on Google Chrome.

## Roadmap

This is mostly a hobby project, but I have some vision of what to do next, namely:

 * Refactor and cleanup client code so it actually looks like a good Haxe code, decrease verbosity, improve maintainability.
 * Incorporate nice fixes/changes from popular engines such as [QuakeSpasm](http://quakespasm.sourceforge.net), such as model animation interpolation, console usability improvements and so on.
 * Separate platform-specific code and support compiling to other targets, such as C++ or maybe even Flash/Unity. Also provide async loading and support Web Audio for the HTML5 version.
 * Look into what can we do with regards to QuakeC code. It's probably not really possible to implement Haxe->QC target, but maybe we could provide alternative scripting engine and just use Haxe or HScript for the game logic.
 * After the previous thing is done, look into improving the gameplay, adding some variety and coolness in the spirit of the [Brutal Doom](http://www.moddb.com/mods/brutal-doom) mod.
 * Look into what can/should we do with a server and net code. Look into implementing QuakeWorld stuff maybe.

So in the end I'd like to see a modernized Quake game that provides a fresh feeling for such an awesome old game.
