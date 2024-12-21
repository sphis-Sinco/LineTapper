package lt.objects.play;

import lt.states.PlayState;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.util.FlxGradient;
import lt.backend.MapData.LineMap;
import lt.objects.play.Player.Direction;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;

class TileGroup extends FlxTypedSpriteGroup<Tile> {
    public inline function getFirstNextTile(time:Float) {
        var tile:Tile = null;
        
        for (nTile in members) {
            if (nTile == null) continue;
            if (nTile.time > time) {
				tile = nTile;
				break;
			}
        }
        return tile;
    }

    public inline function getFirstLastTile(time:Float) {
        var tile:Tile = null;
        for (nTile in members) {
            if (nTile == null) continue;
			if (nTile.time <= time) 
				tile = nTile;
        }
        return tile;
    }

    public inline function getFirstHitable(direction:Direction):Tile {
        var curTile:Tile = null;
        forEachAlive((tile:Tile) -> {
            if (tile.length > 0 ? tile.beenHit && tile.holdFinish : tile.beenHit) 
                return;
            if (!tile.hitable || tile.invalid) 
                return;
            if (curTile != null) {
                if (tile.time < curTile.time) {
                    curTile = tile;
                    return;
                }
            } else {
                curTile = tile;
            }
        });
        return curTile;
    }

    public inline function getLastTile():Tile {
        var curTile:Tile = null;
        forEachAlive((tile:Tile) -> {
            if (curTile != null) {
                if (tile.time > curTile.time) {
                    curTile = tile;
                }
            } else {
                curTile = tile;
            }
        });
        return curTile;
    }
}

typedef TileSignal = FlxTypedSignal<Tile->Void>;

/**
 * A gameplay group used in PlayState as well in editors.
 */
class GameplayStage extends FlxSpriteGroup {
    public var background:FlxSprite;
    public var tiles:TileGroup;
    public var player:Player;
    public var started:Bool = false;

    public var dummyTile:Tile;
    private var conduct:Conductor;

    public var onTileHit:TileSignal;
    public var onTileMiss:TileSignal;
    public var parent:PlayState;
    public var editing:Bool = false;
    public function new(parent:PlayState){
        super();
        this.parent = parent;
        conduct = Conductor.instance;
		background = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [FlxColor.BLACK, FlxColor.BLUE], 1, 90, true);
		background.scale.set(1, 1);
		background.scrollFactor.set();
		background.alpha = 0.1;
        background.active = false;
		group.add(background);

        dummyTile = new Tile(0,0,DOWN,0);
        tiles = new TileGroup();
        add(tiles);

        player = new Player(0,0);
        add(player);

        onTileHit = new TileSignal();
        onTileMiss = new TileSignal();
    }
    
    public function start() {
        // add more stuff here soon
        started = true;
    }

    var _desyncCount:Int = 0;
	public var paused:Bool = false;
    override function update(elapsed:Float) {
        if (!editing) {
			if (!paused){if (!started) 
                return super.update(elapsed);
    
            conduct.time += elapsed*1000*parent.playbackRate;
            if (Math.abs(conduct.time - (FlxG.sound.music.time)) > 50) {
                conduct.time = FlxG.sound.music.time;
                FlxG.watch.addQuick("Desync Count", ++_desyncCount);
            }
            _updateGameplay(elapsed);
            _updateTiles(elapsed);
            _updatePlayer(elapsed);   } 
        } else {
            player.editing = editing;
            tiles.forEachAlive((tile:Tile) -> {
                tile.active = tile.editing = editing;
            });
        }

        super.update(elapsed);
    }

    private function _updateGameplay(elapsed:Float) {
        tiles.forEachAlive((tile:Tile) -> {
            if (tile.missed)
                return;
            if (tile.length > 0 && tile.beenHit && conduct.time > tile.time && conduct.time < tile.time + tile.length) {
                if (FlxG.keys.pressed.ANY) {
                    player.startGlow(tile.color);
                } else {
                    tile.beenHit = false;
                    tile.missed = true;
                }
            }

            if (tile.invalid) {
                _onTileMiss(tile);
            }
        });
        if (FlxG.keys.justPressed.ANY) {
            var tile:Tile = tiles.getFirstHitable(player.direction);
            if (tile != null)
                _onTileHit(tile);
        } 
    }

    private function _updateTiles(elapsed:Float) {
        tiles.forEachAlive((tile:Tile) -> {
            tile.active = tile.canUpdate; // Hi
            if (!tile.canUpdate && conduct.time > tile.time) {
                removeTile(tile);
            }
        });
    }

    private function _updatePlayer(elapsed:Float) {
        var scaleRn:Float = (FlxEase.expoOut((conduct.time % conduct.beat_ms) / conduct.beat_ms)*0.2);
        player.scale.set(1+(0.2-scaleRn), 1+(0.2-scaleRn));
        var nextTile:Tile = tiles.getFirstNextTile(conduct.time);
        var lastTile:Tile = tiles.getFirstLastTile(conduct.time);
        FlxG.watch.addQuick("hmm", nextTile + " // " + lastTile);
		if (nextTile != null && lastTile != null) {
            if (player.direction != lastTile.direction) 
                player.direction = lastTile.direction;

            FlxG.watch.addQuick("Method", "NEW");

			var targetTime:Float = nextTile.time;
			var lastTime:Float = lastTile.time;
			var curTime:Float = conduct.time;
		
			if (targetTime != lastTime) {
				var progress:Float = (curTime - lastTime) / (targetTime - lastTime);
				player.x = lastTile.x + (nextTile.x - lastTile.x) * progress;
				player.y = lastTile.y + (nextTile.y - lastTile.y) * progress;
			}
		} else { // Use legacy method of movement
            FlxG.watch.addQuick("Method", "LEGACY");
			var addX:Float = 0;
			var addY:Float = 0;
	
			elapsed *= 1000*parent.playbackRate;
	
            var boxSize:Float = Player.BOX_SIZE;
			var moveVel:Float = ((boxSize / conduct.step_ms)) * elapsed;
	
			switch (player.direction) {
				case Direction.LEFT:
					addX -= moveVel;
				case Direction.DOWN:
					addY += moveVel;
				case Direction.UP:
					addY -= moveVel;
				case Direction.RIGHT:
					addX += moveVel;
                default:
                    // dont
			}
	
			player.x += addX;
			player.y += addY;
	
			/*if (player.direction == Direction.LEFT || player.direction == Direction.RIGHT) {
				player.y = Math.round(player.y / boxSize) * boxSize;
			} else if (player.direction == Direction.UP || player.direction == Direction.DOWN) {
				player.x = Math.round(player.x / boxSize) * boxSize;
			}*/
		}
    }

    /**
     * Generates the tile objects based of LineMap.
     * @param map LineMap.
     */
    public function generateTiles(map:LineMap) {
		var curDir:Direction = Direction.DOWN;
		var tilePos:Array<Float> = [0, 0];
		var curTime:Float = 0;

        for (tile in map.tiles) {
            var timeDiff:Float = (tile.time - curTime) / (Conductor.instance.step_ms);
            curTime = tile.time;

            var direction:Direction = cast tile.direction;

            switch (curDir) {
				case Direction.LEFT:
					tilePos[0] -= timeDiff;
				case Direction.RIGHT:
					tilePos[0] += timeDiff;
				case Direction.UP:
					tilePos[1] -= timeDiff;
				case Direction.DOWN:
					tilePos[1] += timeDiff;
                default: 
                    // do nothin
            }
            var pos:{x:Float,y:Float} = {
                x: tilePos[0] * Player.BOX_SIZE,
                y: tilePos[1] * Player.BOX_SIZE,
            }

            addTile(new Tile(pos.x, pos.y, direction, curTime+conduct.offset,tile.length));

            curDir = direction;
        }

        trace("Tiles: " + tiles.length);
    }

    public function addTile(tile:Tile) {
        tiles.add(tile);
    }

    public function removeTile(tile:Tile) {
        tile.kill();
        tiles.remove(tile);
        tile.destroy();
    }

    public function updateTileDirections() {
        if (!editing) return;
    
        var lastTile:Tile = null;
        tiles.members.sort((a:Tile, b:Tile)->{
            var result:Int = 0;
    
            if (a.time < b.time)
                result = -1;
            else if (a.time > b.time)
                result = 1;
    
            return result;
        });
        tiles.forEachAlive((tile:Tile) -> {
            if (lastTile != null) {
                if (tile.x > lastTile.x) {
                    lastTile.direction = RIGHT;
                } else if (tile.x < lastTile.x) {
                    lastTile.direction = LEFT;
                } else if (tile.y > lastTile.y) {
                    lastTile.direction = DOWN;
                } else if (tile.y < lastTile.y) {
                    lastTile.direction = UP;
                } else {
                    lastTile.direction = UNKNOWN;
                }
            }
            lastTile = tile;
            lastTile.direction = UNKNOWN;
        });

        trace("Done");
    
        if (lastTile != null) lastTile.direction = UNKNOWN;
    }
    

    private function _onTileHit(tile:Tile) {
        if (tile == null) return;

        tile.beenHit = true;
        onTileHit.dispatch(tile);
    }

    private function _onTileMiss(tile:Tile) {
        if (tile == null) return;
        tile.missed = true;
        player.startMiss();
        FlxG.camera.shake(0.01,0.05);

        onTileMiss.dispatch(tile);
    }
}