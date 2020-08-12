Objective-C And Swift Dependencies Visualizer
==========================  
This is the tool, that can use .o(object) files to generate dependency graph.  
All visualisations was done by [d3js](http://d3js.org/) library, which is just awesome!  
This tool was made just for fun, but images can show how big your project is, how many classes it have, and how they linked to each other    

![Image example](https://pbs.twimg.com/media/CFDYofdUsAAzjSK.png:large)  

### To Install
```
$ git clone https://github.com/tinder-chanyash/objc-dependency-visualizer.git ;
$ [sudo] gem install xcodeproj
$ cd objc-dependency-visualizer ;
```

### To generate dependency graph (Swift projects)
```
[You need to run your project at least once before running this command]
$ ./generate-objc-dependencies-to-json.rb -w -s Tinder > origin.js
$ open index.html
```

### To analysis list of leaf nodes 
```
[You need to run your project at least once before running this command]
$ ./generate-objc-dependencies-to-json.rb -w -s Tinder -f json -o origin.json
$ ./generate-leaf-nodes-filelist.rb -s Tinder -p [PATH_TO_REPO] -i origin.json > origin.txt
[Now you can import to spreadsheet with origin.txt for analysis]
```

### More specific examples
Examples are [here](https://github.com/PaulTaykalo/objc-dependency-visualizer/wiki/Usage-examples)

### Tell the world about the awesomeness of your project structure
Share image to the Twitter with [#objcdependencyvisualizer](https://twitter.com/search/realtime?q=%23objcdependencyvisualizer) hashtag


### Hard way - or "I want to read what I'm doing!"

Here's [detailed description](https://github.com/PaulTaykalo/objc-dependency-visualizer/wiki) of what's going on under the hood
