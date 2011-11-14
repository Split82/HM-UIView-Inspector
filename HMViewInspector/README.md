HM UIView Inspector
===================

HM UIView Inspector is a simple tool which can be included into any iOS project in development to help inspect all actualy visible UIViews. This project is a test application where you can see how exactly this works. This was programmed from scratch without any planning, so code is a little bit messy as the final idea changed many times during development.

Use
---

To be able to inspect your view hierarchy, include these 4 files into your project  `HMInspectorView.h`, `HMInspectorView.m`, `HMViewInspector.h` and `HMViewInspector.m`.
To enable basic inspection call `[[HMViewInspector sharedHMViewInspector] enableDefaultInspectionTrigger];` after your main `UIWindow` is available . The view hierarchy inspector will show up after triple tap.
You can also set your own `UIGestureRecognizer` to call `presentInspectorViewHierarchy`.

Known bugs
----------
As this is alpha version a lot of features are missing and there are also some limitations.

1. First of all there is no support for landscape mode. 
2. When switching to inspect mode your app shouldn't do any special changes to UIViews.
3. There is no support for few `CALayer` elements like `roundedRect` ...
4. This is `UIView` inspector. Everything out of view hierarchy is ignored (independent CALayers)
