# Tiny Toy Heist: Toy Catalog

**Every toy in Tiny Toy Heist: 105 originals across 6 room sets, 3 event lines and 3 specials.** This replaces the earlier 28-toy launch roster as the source of truth for names, rarities and money.

Snapshot of the "Toy Catalog" tab, 18 Oct 2026. Live version: https://claude.ai/code/artifact/0ed341c5-17c5-4d87-af8c-479b7f472662

**Models (19 Oct 2026):** every toy here is a voxel model built from data in `src/ReplicatedStorage/Shared/Toys/Sets/` (one file per set, with each toy's blocks, idle animation and effect), built into Studio at `ServerStorage.TinyToyHeistAssets.Toys`. The game code reads names, rarities and money from there, so change a toy in both places. Review page: `design/toy-turntables.html`. How to design one in the data: `tools/toys/README.md`. Mutations (10, three new: Candy, Bubble, Frozen) are in the main plan's Mutations table.

## How a toy is picked

**Every room has its own set of 14 toys, and deeper rooms pay more for the same rarity.** A Garage Common earns about 10x a Bedroom Common, so each new room feels like a big jump.

### The roll, step by step

1. **A spawn point empties** (someone took its toy, or the Giant goes back to bed and resets the room).
2. **Size roll** from that room's size mix (table below).
3. **Rarity roll** from that size's odds (the Odds by size table in the main plan).
4. **Toy roll:** pick one toy at random from that room's set at that rarity. Every room has at least one toy at every rarity from Common to Mythic.
5. **Secret check:** Giant blankets have a 0.1% Secret chance. That gives The Original Teddy, or the active event's Secret.
6. **Event swap:** during an event, 15% of spawns are swapped for an event toy of the same rarity.
7. **Mutation roll** happens later, at wake-up in the player's hole.

### Rooms: size mix and value

| Room | Small | Medium | Large | Giant | Money multiplier | Common to Mythic range |
| --- | --- | --- | --- | --- | --- | --- |
| Kid's Bedroom | 70% | 30% | 0% | 0% | x1 | $2 to $15,000 /s |
| Hallway | 50% | 50% | 0% | 0% | x1.5 | $3 to $25,000 /s |
| Kitchen | 0% | 60% | 40% | 0% | x2.5 | $5 to $50,000 /s |
| Living Room | 0% | 50% | 50% | 0% | x5 | $10 to $120,000 /s |
| Garage | 0% | 0% | 70% | 30% | x10 | $20 to $250,000 /s |
| Attic | 0% | 0% | 60% | 40% | x25 | $50 to $600,000 /s |

### Money bands by rarity (before the room multiplier)

| Rarity | Base money per second | Toys per room |
| --- | --- | --- |
| Common | $2 to $5 | 4 |
| Uncommon | $10 to $20 | 3 |
| Rare | $40 to $80 | 3 |
| Epic | $200 to $400 | 2 |
| Legendary | $1,500 to $3,000 | 1 |
| Mythic | $15,000 to $30,000 | 1 |

**How to read the room tables:** "(MVP)" marks the 15 toys that ship in the first build. Perks only work while the toy sits on a shelf in your hole, and only Epic and above have one, so the reveal of a higher rarity means something beyond money. "Look" is the voxel design brief and also what its black silhouette shows under the Flashlight.

## Kid's Bedroom set (x1)

**Soft bedtime toys: plush, stickers and night-lights.** The starting room, carpeted and quiet, under the Giant Kid's bed.

| Toy | Rarity | Money /s | Look | Idle animation | Perk |
| --- | --- | --- | --- | --- | --- |
| Rubber Duck (MVP) | Common | $2 | Classic yellow duck, orange beak, tiny sailor hat | Waddles in circles, squeaks every few steps | — |
| Sock Puppet (MVP) | Common | $3 | Striped red-white sock with button eyes and a felt tongue | Flops forward, "talks" with its mouth | — |
| Crayon Buddy | Common | $4 | A fat blue crayon with stick legs and a paper wrapper shirt | Doodles squiggles on the floor that fade | — |
| Bouncy Ball | Common | $5 | Glittery pink ball with a smiley face | Bounces in place, higher every third hop | — |
| Yo-Yo Kid | Uncommon | $10 | Round red yo-yo body, string as a tail | Spins up and down on its own string | — |
| Night-Light Owl | Uncommon | $12 | Small plastic owl with a glowing belly | Belly dims and brightens like breathing | — |
| Plush Bunny (MVP) | Uncommon | $15 | Floppy-eared cream bunny with a stitched heart | Hops, then flops over for a nap | — |
| Glow Star Sticker | Rare | $40 | A five-point glow-in-the-dark star with tiny feet | Peels itself off the wall and sticks back on | — |
| Paper Plane Pilot | Rare | $60 | Folded notebook-paper plane with aviator goggles | Loops around the hole ceiling | — |
| Teddy Knight (MVP) | Rare | $75 | Brown teddy in cardboard armour with a pencil sword | Salutes, swings its sword, stands guard | — |
| Pillow Fort Golem | Epic | $220 | A walking fort of stacked pillows, blanket cape | Rebuilds itself when bumped | Raiders take 1 s longer to grab toys next to it |
| Music Box Dancer (MVP) | Epic | $300 | Tiny ballerina on a wind-up music box, pastel pink | Twirls while a soft tune plays | Your carrying noise -5% |
| Cosmic Teddy (MVP) | Legendary | $1,500 | Midnight-blue teddy with star-pattern fur and a moon patch | Floats a little, stars drift off its fur | +3% luck |
| Galaxy Unicorn Plush | Mythic | $15,000 | White plush unicorn, nebula mane, rainbow horn | Gallops in place, leaves a sparkle trail | +5% luck for everyone in the server, your name shown as the source |

## Hallway set (x1.5)

**Stuff kids drop on the way out the door: wind-ups, shoe things, umbrella-stand junk.** Wooden floor, so twice as loud as the Bedroom, and it's the cat's main route.

| Toy | Rarity | Money /s | Look | Idle animation | Perk |
| --- | --- | --- | --- | --- | --- |
| Button Beetle | Common | $3 | A big four-hole coat button with six thread legs | Scuttles sideways, flips onto its back, rights itself | — |
| Shoelace Snake | Common | $5 | A green shoelace with plastic-tip fangs and googly eyes | Slithers in an S-shape, ties itself in a bow | — |
| Marble Buddy | Common | $6 | A cat's-eye marble with tiny arms | Rolls, wobbles to a stop, waves | — |
| Wind-Up Mouse (MVP) | Common | $8 | Grey tin mouse with a brass key on its back | Zooms forward, slows down, winds its own key | — |
| Toy Soldier (MVP) | Uncommon | $15 | Green plastic soldier on its base | Marches in place, stands to attention | — |
| Umbrella Bat | Uncommon | $22 | A tiny black umbrella with bat wings and fangs | Opens and closes like flapping, hangs upside down | — |
| Pogo Frog (MVP) | Uncommon | $30 | Lime frog standing on a red pogo stick | Pogos in place, croaks on each landing | — |
| Rocket Racer (MVP) | Rare | $60 | Red and white race car with rocket boosters | Revs, does a short donut, puffs smoke | — |
| Jack-in-the-Box (MVP) | Rare | $85 | Purple box with a crank; a grinning clown springs out | Cranks itself, pops out, giggles | 10% chance to spook a raider into dropping a toy |
| Slinky Pup | Rare | $120 | A rainbow spring with a puppy head and tail | Stretches across the hole floor and snaps back | — |
| Coat-Hook Kraken | Epic | $330 | A brass coat hook with four curling tentacles, wearing a tiny scarf | Tentacles grab and swing other toys gently | Toys on either side can't be grabbed for the first 3 s of a raid |
| Arcade Joystick Bot | Epic | $600 | A red-ball joystick on a black base with a pixel face screen | Taps its own buttons; its face shows pixel emotions | +1% luck, +2% more for every Rare or better on your shelf (max +5%) |
| Neon Skate Ghost | Legendary | $3,000 | A see-through ghost riding a glowing neon skateboard | Kickflips over other toys, leaves a neon streak | +10% walk speed |
| The Last Battery | Mythic | $25,000 | A huge AA battery with a lightning-bolt face and crackling ends | Sparks jump between its ends; the hole lights flicker | Gadgets recharge 25% faster |

## Kitchen set (x2.5)

**Play-kitchen and food toys, plus a few that crawled out of the sink.** Tile floor (x3 noise), mousetraps under the counters and the Roomba's dock. The first room where Large toys spawn.

| Toy | Rarity | Money /s | Look | Idle animation | Perk |
| --- | --- | --- | --- | --- | --- |
| Sponge Sid | Common | $5 | A yellow-green kitchen sponge with a bubbly grin | Squishes flat and puffs back up, blowing soap bubbles | — |
| Rubber Chicken (MVP) | Common | $8 | Classic floppy yellow rubber chicken | Flops over and lets out a long squawk | — |
| Toy Toaster | Common | $10 | Chrome play toaster with two cartoon eyes on the side | Pops two toast slices into the air and catches them | — |
| Cereal Box Bot | Common | $12 | A cereal box with cardboard arms and a spoon antenna | Pours a few cereal bits, eats them, shrugs | — |
| Spinning Top | Uncommon | $25 | Striped wooden top with a red handle | Spins, wobbles, and falls over dizzy | — |
| Jelly Cube | Uncommon | $38 | A wobbly see-through green jelly with a cherry on top | Jiggles to music only it can hear | — |
| Teapot Tortoise | Uncommon | $50 | A tortoise whose shell is a flowered teapot | Steam puffs from its spout; it sips from a tiny cup | — |
| Bath Shark (MVP) | Rare | $100 | A blue squirt-toy shark with a white belly | Squirts water arcs, swims in a tiny puddle | — |
| Cookie Jar Knight | Rare | $150 | A ceramic cookie jar with a helmet lid and cookie shield | Lifts its lid to guard its cookies | — |
| Whisk Wizard | Rare | $200 | A metal whisk with a pointy hat and a cinnamon-stick wand | Stirs the air into small sparkle swirls | — |
| Robot Dino (MVP) | Epic | $500 | A silver T-rex robot with red light eyes and a wind-up key | Stomps, roars with a beep, tail clanks | +5% money for the toys on either side |
| Microwave Mimic | Epic | $1,000 | A tiny microwave whose door is a mouth with a rotating-plate tongue | Opens, spins its plate, "dings" | Once every 10 min, instantly finishes one toy's wake-up timer |
| King Rubber Duck (MVP) | Legendary | $5,000 | A golden rubber duck with a crown and a velvet cape | Waddles regally; other ducks bow when it passes | All Rubber Ducks earn x3 |
| Golden Spatula Sovereign | Mythic | $50,000 | A golden spatula on a throne made of stacked pancakes | Flips a pancake crown onto its own head | +10% money from every Kitchen toy you own |

## Living Room set (x5)

**Family-room toys: board games, remotes, the fish tank, things lost in the couch.** A quiet rug in the middle and loud wood around the edges. The cat naps on the couch and wakes on noise.

| Toy | Rarity | Money /s | Look | Idle animation | Perk |
| --- | --- | --- | --- | --- | --- |
| Coaster Crab | Common | $10 | A round cork drink coaster with crab claws | Pinches the air, walks sideways | — |
| Brick Buddy | Common | $15 | A red building brick with stubby legs and a face on its studs | Stacks itself on other bricks that aren't there | — |
| Remote Robot | Common | $20 | A TV remote standing up, its buttons arranged as a face | Points itself at things and presses its own buttons | — |
| Couch Coin Gremlin | Common | $25 | A fuzzy grey dust-bunny gremlin hugging a giant coin | Polishes its coin, hides it, looks around | — |
| Puzzle Piece Pup | Uncommon | $50 | A blue jigsaw piece shaped like a dog | Chases its own tab like a tail | — |
| Pawn Knight | Uncommon | $75 | A black chess pawn wearing a horse-head helmet | Hops in L-shapes across the floor | — |
| TV Static Cat | Uncommon | $100 | A cat made of black-and-white TV static, antenna ears | Flickers and glitches between poses | — |
| Domino Dancer | Rare | $200 | A domino tile with pips for eyes and buttons | Tips over and rights itself in a chain dance | — |
| Kite Dragon | Rare | $300 | A diamond kite with a painted dragon face and ribbon tail | Floats near the ceiling, tail rippling | — |
| Fishbowl Diver | Rare | $400 | A tiny brass diving-suit figure inside a round fishbowl | Bubbles rise from its helmet; it waves through the glass | — |
| Snow Globe Spirit | Epic | $1,300 | A snow globe whose snow forms a little ghost face | Shakes itself; snow swirls into shapes | Raiders move 20% slower in your hole |
| Lava Lamp Blob | Epic | $2,000 | An orange-purple lava lamp whose blobs have eyes | Blobs rise and sink, waving at you | Glows; earns double during Nightmare Night |
| Clockwork Dragon | Legendary | $12,500 | A brass dragon made of gears, steam puffing from its nose | Gears turn as it breathes, wings click open | Auto-collects the cash in your hole |
| Grandfather Clock Titan | Mythic | $120,000 | A towering wooden clock with arms, a pendulum heart and a moon dial face | Pendulum swings; it chimes and every toy in the hole pauses | Your Giant timer shows 10 s more warning before every wake-up |

## Garage set (x10)

**Outdoor and mechanical toys: RC cars, sports gear, garden junk, rockets.** Concrete floor (x3 noise), dark corners and rolling tools. The first room where Giant toys spawn, and where co-carry starts to matter.

| Toy | Rarity | Money /s | Look | Idle animation | Perk |
| --- | --- | --- | --- | --- | --- |
| Bolt Bug | Common | $20 | A hex bolt beetle with washer wings | Screws itself into the floor and back out | — |
| Traffic Cone Kid | Common | $30 | A small orange cone with a reflective stripe belt | Tips its point like a hat | — |
| Toolbox Turtle | Common | $40 | A turtle whose shell is a red metal toolbox | Opens its shell, pulls out a tiny wrench, tightens nothing | — |
| Tennis Ball Tank | Common | $50 | A fuzzy tennis ball on tiny treads with a straw cannon | Rolls forward, fires a fuzz puff | — |
| Hula Hoopster | Uncommon | $100 | A stick figure made of bent hula hoops | Hula-hoops nonstop | — |
| Bike Bell Bird | Uncommon | $150 | A chrome bike bell with a beak and handlebar wings | Rings itself, chirps | — |
| RC Monster Truck | Uncommon | $200 | A giant-wheeled blue RC truck with a flame decal | Pops wheelies and bounces on its suspension | — |
| Garden Gnome Rogue | Rare | $400 | A gnome with a mask, a tiny sack and sneaky tiptoe pose | Tiptoes around, peeks from behind other toys | — |
| Go-Kart Gecko | Rare | $600 | A green gecko driving a soapbox go-kart | Drifts in circles, honks a squeaky horn | — |
| Water Rocket Rhino | Rare | $800 | A rhino strapped to a pump-up water-bottle rocket | Pumps, launches a few studs, splashes down | — |
| Drone Dragonfly | Epic | $2,500 | A quadcopter drone with dragonfly wings and LED eyes | Hovers and scans with a little spotlight | Your Periscope gadget lasts 50% longer |
| Lawn Mower Mecha | Epic | $4,000 | A red push mower that stands up into a robot | Transforms back and forth, revs | Mousetraps in your hole rearm twice as fast |
| Rocket Bike Phoenix | Legendary | $25,000 | A flaming bird fused with a BMX bike, wheels on fire | Pedals in place while flames rise off its wings | +15% carry speed for Large and Giant toys |
| Moon Rocket Rex | Mythic | $250,000 | A T-rex in a silver space suit riding a cardboard moon rocket | Countdown, launch shudder, lands with a stomp | +10% money for the whole hole |

## Attic set (x25)

**Forgotten antique toys: a little spooky, never scary.** Unlocks after Rebirth 1. Creaky boards, always dim, and where Nightmare Night starts.

| Toy | Rarity | Money /s | Look | Idle animation | Perk |
| --- | --- | --- | --- | --- | --- |
| Moth Puppet | Common | $50 | A felt moth on strings with button eyes | Flutters toward any light in the hole | — |
| Picture Frame Phantom | Common | $75 | An empty gold frame with a friendly face drifting inside | Its face swaps silly expressions | — |
| Thimble Knight | Common | $100 | A silver thimble helmet on a matchstick body with a needle lance | Jousts with nothing, bows | — |
| Rocking Horse Foal | Common | $125 | A small painted rocking horse with a yarn mane | Rocks back and forth, neighs softly | — |
| Cuckoo Bird | Uncommon | $250 | A carved bird that lives in a tiny clock house | Pops out of its house every 30 s: "cuckoo!" | — |
| Porcelain Penguin | Uncommon | $375 | A glossy white and blue porcelain penguin | Slides on its belly, clinks to a stop | — |
| Gramophone Frog | Uncommon | $500 | A frog whose mouth is a gramophone horn | Plays a crackly old tune, taps a foot | — |
| Trunk Mimic | Rare | $1,000 | A tiny travel trunk with stickers and a tongue | Snaps its lid, burps out a sock | — |
| Candle Wisp | Rare | $1,500 | A melted candle stub with a dancing blue flame face | Flame stretches and curls like it's talking | — |
| Tin Robot Elder | Rare | $2,000 | A rusty vintage tin robot with a long white tin beard | Walks stiffly, winds down, sighs steam | — |
| Marionette Maestro | Epic | $6,000 | A wooden puppet in a conductor's coat, strings going up to nothing | Conducts; other toys in the hole move to its beat | Toys in your hole earn +5% while it's conducting (always on) |
| Steam Train Serpent | Epic | $10,000 | A wind-up toy train whose carriages form a snake | Chugs in a figure eight, whistles | Dropped stolen toys of yours slide home in 8 s instead of 15 s |
| Attic Owl Oracle | Legendary | $60,000 | A great horned owl carved from wood, glowing amber eyes, an hourglass at its feet | Turns its head all the way round, hoots, the hourglass flips | Shows which size tag in the server hides the rarest toy, once every 15 min |
| Chandelier Leviathan | Mythic | $600,000 | A crystal chandelier shaped like a sea serpent, candle-lit, chains as fins | Coils slowly overhead, crystals chiming | +20% money for the whole hole, and your hole glows from across the house |

## Event toys (18)

**Event toys spawn in any room you've unlocked and earn the same everywhere, priced at the Living Room level (x5).** During an event, 15% of spawns are swapped for event toys, and the Event Crate (with odds shown) sells them too. When the event ends they stop spawning forever, which is what makes them worth showing off.

### Halloween line (7): October

The game won't be out for Halloween 2026, so this line is ready for the first October after launch.

| Toy | Rarity | Money /s | Look | Idle animation | Perk |
| --- | --- | --- | --- | --- | --- |
| Pumpkin Pup | Uncommon | $75 | A carved pumpkin puppy with a glowing grin and a vine tail | Chases its own stem | — |
| Bedsheet Ghost | Rare | $250 | A kid-sized bedsheet ghost with sneakers poking out underneath | Says "boo" and startles itself | — |
| Candy Corn Cobra | Rare | $350 | A striped candy-corn snake with a wrapper rattle | Rattles its wrapper, flicks a licorice tongue | — |
| Witch Hat Hamster | Epic | $1,500 | A hamster in an oversized witch hat riding a toothbrush broom | Loops around the hole on its broom | Squeaky Decoy recharges 30% faster |
| Skeleton Xylophone | Epic | $2,000 | A grinning skeleton playing a tune on its own ribs | Plays a spooky jingle, bows | Your Alarm Bell also stuns raiders for 1 s |
| Jack-o'-Lantern King | Legendary | $15,000 | A huge pumpkin wearing a crown of candles, vine cape | Its candles flare as it laughs | +10% luck during any event |
| Headless Hobby Horse | Mythic | $150,000 | A hobby-horse stick whose head is a floating flaming jack-o'-lantern | Gallops in place; its head bobs a beat behind | +15% money for the whole hole during any event |

### Nightmare Night line (6): recurring, every 30 minutes

These only spawn while the lights are out. Glow mutations are common on them.

| Toy | Rarity | Money /s | Look | Idle animation | Perk |
| --- | --- | --- | --- | --- | --- |
| Glow Worm | Common | $10 | A chubby green worm with a glowing tail tip | Inches along, tail pulsing | — |
| Nightlight Nibbler | Uncommon | $50 | A plug-in nightlight with tiny teeth | Chomps at the shadows around it | — |
| Shadow Puppet Wolf | Rare | $300 | A hand-shadow wolf that only exists where light hits a wall | Howls silently, its ears flick | — |
| Under-Bed Lurker | Epic | $1,800 | A shy fuzzy purple monster with very long arms and big eyes | Hides behind its own arms, peeks out | During Nightmare Night, the Giant can't see you while you stand still |
| Closet Monster Plush | Legendary | $15,000 | A big soft plush monster with closet-door wings and a coat-hanger smile | Creaks its doors open, waves | One extra Nightmare Night spawn appears near your hole |
| The Night Watchman | Secret | $2,000,000 | A tall plush night guard with a lantern and a crescent moon for a face | Walks a slow patrol; its lantern sweeps the hole | Your noise adds 30% less to the Wake Meter; gold "Watchman" chat tag |

The Night Watchman replaces The Original Teddy as the Secret roll on Giant blankets during Nightmare Night.

### Winter line (5): December, the week 8 seasonal event

| Toy | Rarity | Money /s | Look | Idle animation | Perk |
| --- | --- | --- | --- | --- | --- |
| Snowball Seal | Common | $15 | A seal made of packed snowballs with a scarf | Rolls into a ball and back | — |
| Ornament Owl | Uncommon | $60 | A glass bauble owl with a hook hat | Spins slowly, reflecting light | — |
| Gingerbread Golem | Rare | $350 | A big gingerbread figure with icing armour and gumdrop buttons | Stomps; crumbs fall off and it frowns | — |
| Nutcracker Captain | Epic | $2,000 | A painted wooden nutcracker with a tall hat and a cracked walnut shield | Snaps its jaw, marches | The Pencil Bonk needs 1 hit instead of 2 to make a thief drop |
| Aurora Reindeer | Mythic | $150,000 | A crystal reindeer whose antlers glow with northern lights | Ripples of green and purple light pour off its antlers | During the Winter event, your carrying noise -20% (snow on the floors) |

## Special toys (3)

**These can't be rolled from a normal spawn, so owning one says something about you.** Each has a single, specific way to get it.

| Toy | Rarity | Money /s | How you get it | Look | Perk |
| --- | --- | --- | --- | --- | --- |
| The Original Teddy | Secret | $1,500,000 | 0.1% Secret roll on any Giant blanket; at most one spawns per server per hour. Server-wide banner and a sound when it spawns, before anyone knows where | A worn, patched, one-eyed brown teddy with a faded name tag reading "#1"; a soft golden halo | +25% money for the whole hole; gold "Original" chat tag |
| Growth Chart Giraffe | Mythic | $300,000 | Reward for Rebirth 3 | A wooden height-chart giraffe with pencil marks and dates up its neck | +5% money for every rebirth you've done |
| Index Teddy | Epic (always Gold) | $5,000 | Reward for finding all 84 room-set toys in the Toy Index | A teddy made of book pages, a bookmark ribbon tail, gold-leaf edges | +5% luck forever |

**Secret spawn rules:** when a Secret is rolled, the blanket is Giant-sized and gives off a constant rainbow shimmer under the Flashlight, so the whole server races for it. It can't be co-carried, so only one player can take it home, and it's the best clip moment in the game.

## Shelf combos (14)

**Certain toys boost each other when they're on display in the same hole.** Combos give cheap toys a reason to keep, make players hunt specific toys rather than only rarity, and add a discovery layer: each combo stays hidden in the Index as "???" until you complete it the first time.

- All listed toys must be on your shelves at the same time (any slots).
- Glowing lines connect the toys in an active combo, so visitors can see it.
- A stolen toy breaks the combo for its victim, which gives raids a second sting.
- Combos don't stack with themselves; different combos do stack.

| Combo | Toys needed | Bonus |
| --- | --- | --- |
| Knights of the Shelf | Any 3 of Teddy Knight, Pawn Knight, Cookie Jar Knight, Thimble Knight | Those knights earn x2 |
| Royal Court | King Rubber Duck + 3 Rubber Ducks | +5% luck |
| Tea Party | Teapot Tortoise + Porcelain Penguin + Plush Bunny | Those three earn +50% |
| Breakfast Club | Toy Toaster + Cereal Box Bot + Sponge Sid | All Kitchen toys earn +15% |
| Game Night | Domino Dancer + Pawn Knight + Puzzle Piece Pup | +5% luck |
| Wind-Up Gang | Wind-Up Mouse + Robot Dino + Tin Robot Elder + Clockwork Dragon | Wake-up timers -20% |
| Dino Duo | Robot Dino + Moon Rocket Rex | Both earn +25% |
| Flying Squad | Paper Plane Pilot + Kite Dragon + Drone Dragonfly + Umbrella Bat | +10% walk speed |
| Speed Demons | Rocket Racer + Go-Kart Gecko + RC Monster Truck + Neon Skate Ghost | +10% carry speed |
| Splash Zone | Bath Shark + Fishbowl Diver + Water Rocket Rhino | The first raider each minute slips on entering (1 s stun) |
| Music Hour | Music Box Dancer + Gramophone Frog + Cuckoo Bird + Skeleton Xylophone | +10% money for the whole hole |
| Lucky Stars | Glow Star Sticker + Cosmic Teddy + Galaxy Unicorn Plush | +5% luck |
| Night Shift | Night-Light Owl + Glow Worm + Lava Lamp Blob | +20% money for the whole hole during Nightmare Night |
| Haunted House | Candle Wisp + Picture Frame Phantom + Bedsheet Ghost + Snow Globe Spirit | Haunted mutation chance x2 during Halloween |

## Rules for designing new toys

**Every new toy has to pass these checks before it goes in an update.** They keep the catalog consistent, legal and easy to build.

1. **Original only.** No characters, names or designs from movies, shows, games or brands (no Toy Story, Pokémon, LEGO-branded bricks, real candy brands). Use generic objects and new names.
2. **One-glance silhouette.** Under the Flashlight its black shape must say what it is: a duck reads as a duck. If two toys have the same silhouette, change one.
3. **Toy + twist naming.** An everyday object plus a creature or job: "Coat-Hook Kraken", "Whisk Wizard". Two or three words, easy to say in a TikTok.
4. **It fits its room.** Bedroom = soft and bedtime; Hallway = dropped and wind-up; Kitchen = food and sink; Living Room = games and couch; Garage = outdoor and mechanical; Attic = antique and spooky-cute.
5. **Voxel budget by rarity.** Common 40–60 blocks, Uncommon 60–80, Rare 80–100, Epic 100–140 plus one particle effect, Legendary and up 140–200 plus an aura.
6. **One idle animation, readable in 2 seconds,** with one sound. Rarer toys get a louder, longer reveal sting.
7. **Money inside its band.** Use the base band for its rarity, then the room multiplier. Never price a new toy above the top of its band; add a new rarity tier instead.
8. **Perks: Epic and up only, one line, and no pay-to-win.** A perk can boost money, luck, speed, noise or defence by up to about 25%. It can never make you un-raidable or let you skip the Giant entirely.
9. **Fill every rarity in a new room set:** 4 Common, 3 Uncommon, 3 Rare, 2 Epic, 1 Legendary, 1 Mythic.
10. **Give it a combo hook** where it fits naturally, so the new toy matters to people who already have a full shelf.

### Toy design template

Copy this when proposing a toy (in a TikTok poll, a comment, or here):

```
Name:
Room set / event:
Rarity:
Money per second:
Look (voxel brief, 1 sentence):
Idle animation (1 sentence):
Sound:
Perk (Epic+ only):
Combo it belongs to (optional):
```
