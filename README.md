# SCStackViewController

SCStackViewController is a container view controller which allows you to stack other view controllers on the  top/left/bottom/right of the root and build custom transitions between them while providing correct physics and appearance calls.

SCStackViewController is a little bit from the all the other stack implementations available. It was build with the following points in mind:

1. Simple to understand and modify
2. Left/right and top/bottom stacking
3. Correct physics
4. Correct appearance calls
5. Customizable transitions
6. Pagination
7. Customizable interaction area
8. Completion blocks for everything

## Implementation details

SCStackViewController comes in at just under 500 lines and is build on top of an UIScrollView which gives us the physics we need, content insets for all the 4 positions, callbacks for linking the custom transitions to and easy to build pagination. By overriding the scrollView's shouldReceiveTouch: method we also get the customizable interaction area.

The stack itself relies on layouters to know where to place the stacked controllers at every point. They are build on top of a simple protocol and the demo project contains 6 examples with various effects.

## Examples

##### Plain Stack Layouter
It places the view controllers to their final position and doesn't modify them while dragging.

![PlainStackLayouter](https://dl.dropboxusercontent.com/u/12748201/Recordings/Plain.gif)

##### Reversed Stack Layouter
Reverses the direction used in the plain layouter

![ReversedStackLayouter](https://dl.dropboxusercontent.com/u/12748201/Recordings/Reversed.gif)

##### Sliding Stack Layouter
It reveals every new controller from beneath the previous one through sliding

![SlidingStackLayouter](https://dl.dropboxusercontent.com/u/12748201/Recordings/Sliding.gif)

##### Parallax Stack Layouter
Add a nice parallax effect while revealing the stacked controllers

![ParallaxStackLayouter](https://dl.dropboxusercontent.com/u/12748201/Recordings/Parallax.gif)

##### GoogleMaps Stack Layouter
The effect seen in the Google Maps app when opening the drawer

![GoogleMapsStackLayouter](https://dl.dropboxusercontent.com/u/12748201/Recordings/GoogleMaps.gif)

##### MerryGoRound Stack Layouter
Just something I was playing with.. :)

![MerryGoRoundStackLayouter](https://dl.dropboxusercontent.com/u/12748201/Recordings/MerryGoRound.gif)

## Usage

- Import the stack into your project

```
#import "SCStackViewController.h"
```

- Create a new instance

```
stackViewController = [[SCStackViewController alloc] initWithRootViewController:rootViewController];
```
 
- Set a touch refusal area (optional)

```
[stackViewController setTouchRefusalArea:[UIBezierPath bezierPathWithRect:CGRectInset(self.view.bounds, 50, 50)]]
```
 
- Register layouters

```
id<SCStackLayouterProtocol> layouter = [[SCParallaxStackLayouter alloc] init];
[stackViewController registerLayouter:layouter forPosition:SCStackViewControllerPositionLeft];
```

- Push view controllers

```
[self.stackViewController pushViewController:leftViewController 
								  atPosition:SCStackViewControllerPositionLeft 
								  	  unfold:NO 
								  	animated:NO 
								  completion:nil];
```

######Check out the demo project for more details.

## License
SCStackViewController is released under the GNU GENERAL PUBLIC LICENSE (see the LICENSE file)

## Contact
Any suggestions or improvements are more than welcome.
Feel free to contact me at [stefan.ceriu@yahoo.com](mailto:stefan.ceriu@yahoo.com) or [@stefanceriu](https://twitter.com/stefanceriu).