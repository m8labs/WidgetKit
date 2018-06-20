
# WidgetKit for iOS &nbsp; [![Tweet](https://img.shields.io/twitter/url/http/shields.io.svg?style=social)](https://twitter.com/intent/tweet?text=Create%20native%20iOS%20apps%20in%20Xcode%20without%20a%20code!&url=https://github.com/faviomob/WidgetKit&hashtags=WidgetKit_iOS,Xcode,iOS)

[![Platform](https://img.shields.io/badge/platform-iOS-aaaaaa.svg?style=flat)](#Installation)
[![Twitter](https://img.shields.io/badge/twitter-@faviomob-1da1f2.svg?style=flat)](http://twitter.com/faviomob)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](#Carthage)


_WidgetKit_ framework allows you to compose native apps without a code and load them as `NSBundle` into another app dynamicly from local or remote locations. No executables will be downloaded and loaded into memory, because widgets contain none of them. All logic and data flow are based on `NSPredicate` and `NSExpression`.

> _WidgetKit_ uses technique of _mediating controllers_, which were introduced in _Cocoa Bindings_ (`NSController` and its descendants in _AppKit_ for _macOS_). Although, this is not direct port of it. Read more about this [here](https://developer.apple.com/library/archive/documentation/General/Conceptual/CocoaEncyclopedia/Model-View-Controller/Model-View-Controller.html#//apple_ref/doc/uid/TP40010810-CH14-SW7).

_WidgetKit_ view controllers consist of predefined and 100% reusable objects (`NSObject`s), or _mediating controllers_, which control presentation of views inside their view controller. You put these _mediator_ objects onto the view controllers' scene in the _Interface Builder_, set their properties via _User Defined Runtime Attributes_ and connect outlets between them and your UI elements. Or, alternatively, you can load all this setup through corresponding _JSON_ files, and that's what will be described in this document.

## Features:

- Bind _UIKit_ elements to model's fields with data formatting;
- Handle received _JSON_ data and parse it directly to the _CoreData_ (in the background);
- Send forms (with media content) to any http server using plain _UIKit_ controls;
- Populate `UITableView` and `UICollectionView` with various types of data (_JSON_, array of `NSObject` or `NSManagedObject`);
- Handle UIControl's interactions, including infinite scroll and pull to refresh;
- Filter content in `UITableView` and `UICollectionView` via text input fields using predicates;
- Delete content with respecting its ownership. You set ownership rules in _CoreData Model Designer_;
- Propagate content object between view controllers on segue;
- Control presentation of particular UI elements in the view controller when specific data changes;
- Calculate views geometry in the background for faster scrolling;

> _WidgetKit_ is not a set of ready-to-use views and view controllers. Your _UI_ is completly under your control.

## Examples

- *WidgetDemo* - main example, open it to follow explanations below.
- *WidgetHostDemo* - widgets loader. This example is on the picture below and uses loading code similar to what is used in the beginning of the _Usage_ section.

> To install, download this repo, in _Terminal_ go to the "_Samples/***Demo_" directory and run `pod install` command.

- *TwitterDemo* - complex "real life" example with custom code integration. You can download it [here](https://github.com/faviomob/WidgetKitSamples).

<p align="center"><i>WidgetHostDemo.GIF</i></p>
<p align="center"><img width="272" src="https://github.com/faviomob/WidgetKit/raw/master/Samples/Resources/WidgetHostDemo.gif"></p>


## Installation

##### CocoaPods

To install via [CocoaPods](http://cocoapods.org) add this line to your `Podfile`:

```bash
pod 'WidgetKit'
```
Then run `pod install` command.

##### Carthage

To install via [Carthage](https://github.com/Carthage/Carthage) add this to your `Cartfile`:

```bash
github "faviomob/WidgetKit"
```
Run `carthage update --platform iOS` to build the frameworks and drag built "*.framework" files into your _Xcode_ project. Then open _Build Phases_ section of your target and add new _Copy Files Phase_ by pressing "+" button at the top left corner. Choose _Frameworks_ as destination and add all the frameworks you've just dragged into the project.

## Usage

First, let's see how you can integrate external `NSBundle` to yout host application. Drag new `UIView` to your view controller and set its custom class to `WidgetView`. Create `@IBOutlet` for this view in your view controller. Also drag `UIButton` and create `@IBAction` for it. The whole setup should look like this:

```swift

import WidgetKit

class MyHostViewController: UIViewController {
    
    @IBOutlet var remoteWidgetView: WidgetView!

    @IBAction func downloadAction(_ sender: UIButton) {
        sender.isEnabled = false
        remoteWidgetView.download(url: "https://<address>/YourWidget.zip") { widget, error in
            sender.isEnabled = true
        }
    }
}
```

You will also need to set `widgetIdentifier` for the widget view so, that it starts with `bundleIdentifier` of your widget's `NSBundle`. As alternative to the listing above, you can just set `downloadUrl` property of your widget view, but you will not be able to track failure or success manually in this case. All these properties you can set in the `viewDidLoad` method or in the _User Defined Runtime Attributes_ section of the _Interface Bulder_. You can add as many widgets to the host view as you want, but all of them should have different `widgetIdentifier`.

### Building a Widget

Now, let's see how you can create widget app itself. The easiest way to understand how things work is to open the _WidgetDemo_ sample project and run it.

#### Concepts

_WidgetDemo_ project contains `Main.storyboard` file, _CoreData_ `Model` file and a couple of _JSON_ files: one for each view controller, and one for setting up your networking stack.

Let's look at the "FeedViewController.json" and "NewPostViewController.json" files, which contain setup for our view controllers.

> To load this type of files, the view contoller itself should be of `ContentViewController` custom class or its descendant. Also, the `restorationIdentifier` should be set to the name of the _JSON_ file (without extension).

There are four base types of mediator objects you can create in this file, and all of them are inherited from `CustomIBObject` which in its turn is descendant of the `NSObject`:

- BaseContentProvider
- BaseDisplayController
- ActionController
- ActionStatusController

For each particular purpose you create one of the descendants of these four major types. For example, for displaying data inside `UITableView` you should choose `TableDisplayController`, and for setting view controllers' `content` object (which will update all binded UI controls), you create `ContentDisplayController`. For fetching data from `CoreData` store you connect these `BaseDisplayController` objects to the `ManagedObjectsProvider` content provider.

`ActionController` is an object, that can call some network action that you describe in your networking _JSON_, or it can call some _selector_ if you set `target` outlet to it. In case when _selector_ not found, it will try to call network action with the same name instead. The moment, when action happens depends on the concrete descendant of the `ActionController`. For example, for handling buttons pressing you create `ButtonActionController` and connect your button to the `sender` outlet, and `OnLoadActionController` will be triggered after the `viewDidLoad`.

More close look on the networking you will find in the [Networking](#networking) section of this document, but in brief, you have one _JSON_ file (actually two: development and production) with a section for each named action, where you put `path`, `httpMethod`, `parameters`, `resultType` and other attributes of the network call. All parameters are automatically taken and substituted from `ActionController`. Also you have one common section, where you store your `baseUrl` and other defaults. After the network request completes, its response will be automatically parsed into `CoreData` objects in the backgound. The name of the class of objects created you set in the `resultType`.

Each action controller contains `ActionStatusController` in its `status` variable. So you can bind to `status.inProgress` key path and update your labels and activity indicators accordingly. You can also have independent `ActionStatusController` object for situations when action was initiated outside of the current view controller. For example, after loading current user, an action of loading feed content will be called automatically as a chain call (read about chained network calls below). Thus, to track the state of this call you need to create separate `ActionStatusController` object.

#### Fetch & Display

Ok, enough theory, let's move to our example. If you open "FeedViewController.json" you will find two sections in the root node: `objects` and `elements`. The first one should contain mediator objects, and the second one contains bindings for UI elements. You can also use this section to set initial values for properties (see `attrs`) the same way you do it in the _User Defined Runtime Attributes_, but additionally arrays are supported.

The widget starts its work from loading current user. In this sample we omit the authentication part of the networking layer, and assume that we already authenticated. To know how to setup real networking with complex authentication process check the [TwitterDemo](https://github.com/faviomob/WidgetKitSamples) sample app.

To load the current user when widget starts we need `OnLoadActionController` object:

```JSON
"currentUserAction": {
    "type": "OnLoadActionController",
    "attrs": {
        "actionName": "currentUser"
    }
}
```

This will initiate the call to the endpoint named "currentUser" and, upon receiving response _JSON_, `Account` managed object will be created, because the `resultType` attribute of the "currentUser" action was set as "Account" (see _Networking_ section below).

Now we need to fetch this current user account from the local storage. `ManagedObjectsProvider` is used for this:

```JSON
"currentUserProvider": {
    "type": "ManagedObjectsProvider",
    "attrs": {
        "entityName": "Account",
        "resultChain": [
            "wx_first"
        ]
    }
}
```

This object fetches all records with class name `Account` and takes the first one (and only one should actually exist).

`resultChain` is an array of functions you can apply to the fetched data set (you can read the full description of the `resultChain` in the source comments). All in all, we now have our account object and we want to display the name of a user in the title of our view controller. That's what `BaseDisplayController` is for. But in this case we need its descendant `ContentDisplayController`:

```JSON
"currentUserDisplayController": {
    "type": "ContentDisplayController",
    "outlets": {
        "mainContentProvider": "currentUserProvider"
    }
}
```

As you can see, we use _JSON_ object `id` as a reference across the entire view controller. When the "currentUserProvider" has a new data, it asks its consumer (which is "currentUserDisplayController" in this case) to render its content. For the `ContentDisplayController` it means setting the new value for the `content` property of its view controller. What in its turn causes an update for all UI elements, that have bindings. We have only two elements with bindings for this view controller: "titleLabel" and "footerActivityIndicator" (others are for `UITableViewCell`). Let's look at the "titleLabel" first:

```JSON
"titleLabel": {
    "bindings": [
        {
            "to": "text",
            "predicateFormat": "content == nil",
            "ifTrue": "",
            "ifFalse": "$content.name"
        }
    ]
}
```

Here you can see how logic can be integrated within the widget app - `predicateFormat` has a standard syntax of the `NSPredicate(format:)` and is evaluated against the scope of this view controller. So, if the value of `content` property for this view controller is equal to `nil` (i.e. there is no current user), then `text` property of the label will be set to the `ifTrue` expression value (empty string). Otherwise, it will be set to the result of the `content.name` substitution, i.e. `name` of the user.

> For all _UI_ elements, that we refer here, string identifier must be set via `wx.identifier` property in the _User Defined Runtime Attributes_ section of the _Interface Bulder_.

Fine, now we have our view controller set with `content` object, and all elements are updated. Let's see then how we can populate our `UITableView`. First, we need to fetch data for our table, that's what the "homeFeedContentProvider" is for:

```JSON
"homeFeedContentProvider": {
    "type": "ManagedObjectsProvider",
    "attrs": {
        "entityName": "Post",
        "predicateFormat": "favoritesCount > 0",
        "sortByFields": "timestamp",
        "sortAscending": false
    }
}
```

Here we select all `Post` records with `favoritesCount` greater then zero and sort them descending by `timestamp`. To show these fetched objects in our table we need `TableDisplayController`:

```JSON
"tableDisplayController": {
    "type": "TableDisplayController",
    "outlets": {
        "tableView": "tableView",
        "mainContentProvider": "homeFeedContentProvider",
        "searchController": "searchController",
        "emptyDataView": "emptyDataView"
    }
}
```

You can see outlets, that connect our table with `wx.identifier` equal to "tableView" to the "tableDisplayController" and `mainContentProvider` connected to "homeFeedContentProvider". When "homeFeedContentProvider" got some changes in its fetched results, it asks "tableDisplayController" to render its content, that in case of `TableDisplayController` means reload connected `tableView`.

To fullfil `UITableView` cells automatically, you need to set their custom class to `ContentTableViewCell` and create bindings for UI elements inside the cell. We have four elements in the `bindings` section for our cell: "avatarView", "textLabel", "authorLabel" and "timeLabel". The structure for this section is flat, so identifiers inside repeatable content elements, such as table or collection view cells should not intersect with the view controllers elements. Let's look at the binding for "timeLabel" element:

```JSON
"timeLabel": {
    "bindings": [
        {
            "placeholder": "--s",
            "from": "content.timestamp",
            "transformer": "ago"
        }
    ]
}
```

It hasn't `to` field, that means `NSObject.wx_value` property by default, which is overriden for each UI class and equal to `text` property for `UILabel`. Also, it has a `transformer` field, where you can refer to your custom `NSValueTransformer`, or some of the transformers, provided by this framework, f.e. `ago`, that just shows the amount of time passed (hours, days etc.) with a proper localization. All evaluations inside cells are, of cource, performed in the scope of the cell: `content` object is taken from `ContentTableViewCell.content`, not from this view controller's `content`.

#### Search

There are two other outlets in our "tableDisplayController": `emptyDataView` and `searchController`. The first one is just a view that will show up when there is no data to display in the table view. And the second one deserves more detailed explanation. First, look at its listing:

```JSON
"searchController": {
    "type": "SearchActionController",
    "attrs": {
        "actionName": "searchPosts",
        "filterFormat": "text CONTAINS[cd] $input"
    },
    "outlets": {
        "sender": "searchBar"
    }
}
```

As you can see, "searchController" is a descendant of the `ActionController`, that can provide search capability to the table view, connected to the same "tableDisplayController". When you start typing in the "searchBar", "tableDisplayController" replaces its content provider with the content provider of the "searchController" (which is initially the same by default) and adds additional condition in `filterFormat` to the fetch request's `NSPredicate`. The value of `$input` is automatically taken from the "searchBar" `text` property.

Also, if you set `actionName` property, besides just filtering local data, it will ask network layer to make requests. It doesn't flood with requests while you typing, firing events only after you make a short typing pause. You can set this timeout adjusting `actionThrottleInterval` property. After search request completes, its response will be automatically parsed into `CoreData` objects, and if there are new items available, they will be immidiatly displayed in the table view via `ManagedObjectsProvider`->`TableDisplayController` connection.

#### Tracking State

The last object in our file is the "homeFeedStatusController":

```JSON
"homeFeedStatusController": {
    "alias": "homeFeedStatus",
    "type": "ActionStatusController",
    "attrs": {
        "actionName": "homeFeed",
        "errorMessage": "Failed to load feed!"
    }
}
```

Its main purpose is to track status of the "homeFeed" network action, because it is started indirectly after "currentUser" action. Moreover, providing dedicated `ActionStatusController` you have an ability to set an `errorMessage`, which will be shown to the user in case of action failure. Let's look how we can update activity indicators in our view controller with the help of `ActionStatusController`:

```JSON
"footerActivityIndicator": {
    "bindings": [
        {
            "predicateFormat": "currentUserAction.status.inProgress == 1 OR homeFeedStatus.inProgress == 1"
        }
    ]
}
```

In this case, we have left all the attributes of this binding to their default values: `to` defaults to `UIActivityIndicatorView.wx_value`, which is `UIActivityIndicatorView.isAnimating` under the hood, and `ifTrue` / `ifFalse` defaults to `true` / `false` respectively. As you can see we refer to the "homeFeedStatusController" by its `alias`. Thus, "footerActivityIndicator" starts animating when either "currentUser" or "homeFeed" actions are in progress and stops when nothing in progress. Worth to mention, that bindings for `elements` of the `ActionStatusController` are refreshed before and after the action call (if `elements` outlets are not connected - everything refreshed).

#### Error Handling

By default `ActionStatusController` will display `errorMessage` in the `UIAlertController`. Additionally you can provide `errorTitle`. But you can alter this behavior by overriding `ContentViewController.handleError` method:

```swift
class MyViewController: ContentViewController {

    override open func handleError(_ error: Error, sender: ActionStatusController) {
        // oops! it happened!
    }
}
```
Of course, you must include this code into your host application, as widgets should not contain any code at all.

### Networking

Finally, let's dig little bit deeper into networking with _WidgetKit_. First, look at a special `@self` element in the `bindings` section. It used to set properties and their bindings for the current view controller:

```JSON
"@self": {
    "attrs": {
        "serviceProviderClassName": "StubServiceProvider"
    }
}
```

Service provider is just a `NSObject` conforming to `ServiceProviderProtocol`. By default, `StandardServiceProvider` is used, but you can override it for each view controller and for each `ActionController` as well. You do this by setting `serviceProviderClassName` property for the view controller, and `serviceProvider` or `serviceProviderClassName` properties for `ActionController`.

Service provider got its configuration from the object, conforming to `ServiceConfigurationProtocol`. `StandardServiceProvider` uses `StandardServiceConfiguration`, which loads its setup from service description _JSON_ file - "Service.json" (or "Service.dev.json" for development configuration).

Here we use `StubServiceProvider`, a dummy provider, that just responds for each action name with predefined _JSON_ objects from "StubService.json". Also, it shows how you can setup an actual service. Let's start from the `defaults` section:

```JSON
"defaults": {
    "baseUrl": "https://demo.io/v1",
    "httpMethod": "GET",
    "resultKeyPath": ""
}
```

Every parameter here can be overriden in the `actions` section, except `baseUrl`. But you can use full address in the `path` attribute of each action. `resultKeyPath` is a key path in the response dictionary to access actual data. Empty string or absence means that response will be parsed "as is".

Let's move to the `actions` section:

```JSON
"actions": {
    "currentUser": {
        "path": "me",
        "resultType": "Account",
        "nextAction": "homeFeed"
    },
    "homeFeed": {
        "resultType": "[Post]",
        "clearPolicy": "after",
        "parameters": {
            "count": 20
        }
    },
    "newPost": {
        "path": "new",
        "httpMethod": "POST",
        "resultType": "Post",
        "parameters": {
            "message": "$text"
        }
    }
}
```

Note the `nextAction` attribute of the "currentUser" action. This is a "chain call". Chain call are only performed in a case of success of the previous call and takes a parsed object as its argument. If the previous call returned an array, no argument will be passed to the next action. So, the parsed object of the "currentUser" is an `Account` instance, so it will be passed to the "homeFeed" action. But it's just not used there for any substitutions.

Now look at the `resultType` of "homeFeed" action. The class name is enclosed in square braces. It means that response will contain an array. `clearPolicy` is used to clear old data before parsing a new one. `after` means cleaning after request (but before parse), so user will see immidiate replacement of the data, and `before` means that the old data will be removed before request is started, so user will see a blank screen. `parameters` contains `count`, which will be packed to the request's body (it uses `Alamofire.URLEncoding` for this). If you want to pass parameters in the url, put them in the `path` (`$` substitution notation supported).

#### Forms

And we arrived to the culmination of the networking topic - forms submission! Form submission is a breeze with _WidgetKit_. You just need to set a custom class to `FormDisplayView` for a form view and connect `mandatoryFields` / `optionalFields` outlets. Also you will need to set `wx_fieldName` for each form field in the _Interface Builder_ - it will be used as a key in the form's dictionary ("text" in this sample). To see how it works open the second view controler's _JSON_ file - "NewPostViewController.json". You will find this object there:

```JSON
"newPostActionController": {
    "type": "BarButtonActionController",
    "attrs": {
        "actionName": "newPost"
    },
    "outlets": {
        "form": "formView",
        "sender": "postButton"
    }
}
```
And this outlet connection:

```JSON
"formView": {
    "outlets": {
        "mandatoryFields": [
            "textView"
        ]
    }
}
```

"newPostActionController" connects itself to the button with "postButton" identifier and the form with "formView" identifier. Thus, when you press the button, `BarButtonActionController` asks `FormDisplayView` to collect fields values into the dictionary. The values of fields are taken from the `UIView.wx_fieldValue` property, which is overriden for every `UIView` descendant, that can be used as a form field (equals to `UITextView.text` for "textView").

If any of the `mandatoryFields` occurs to be empty, the appropriate view will be "shaked" by default, but you can change this behavior by overriding `FormDisplayView.highlightField` method. If all values are good, "newPost" action will be called with the value of "text" field name substituted in the `parameters` dictionary.

> Your service should return the newly created object, otherwise it will not be displayed, because local object creation is not yet supported.

#### Dates

The last thing I would like to discuss is processing of dates. You can receive various type of date strings from different services. So you might need to provide a proper convertion for them into the `Date` object. You do this by installing date transformer in the `options` section of your service description _JSON_:

```JSON
"options": {
    "transformers": {
        "date": {
            "strToDate": {
                "format": "EEE MMM d HH:mm:ss Z y",
                "locale": "en_US_POSIX"
            }
        }
    },
    "debugDelay": 0.25
}
```

Then you refer this transformer by its `id` in _CoreData Model Designer_ as described [here](https://github.com/gonzalezreal/Groot/blob/master/Documentation/Annotations.md).

`debugDelay` is used by `StubServiceProvider` for simulation of a loading process, so you can check how your _UI_ looks like during network delays.

### Deploy

After you finish all layers of your widget, you will need to properly pack it into the bundle. Thus, build your app as usual, navigate to "Products" group in the _Xcode Project Navigator_ and choose "Show in Finder" in the context menu. Now press `cmd+i` and replace ".app" extension with ".bundle". Then open context menu of this file in _Finder_ and choose "Show Package Contents". It will throw you into the bundle's folder. Now you need to remove everything, that somehow related to an executable code:

app itself (no extension), "Frameworks" folder, any "*.dylib" files, "PkgInfo" file, "CodeSignature" folder.

> You can leave only "*.json", "*.momd", "*.car", "*.storyboardc", "*.nib" files, any images and "Info.plist".

After this total cleanup, you can include this bundle into your host application directly and load it via `WidgetView.load(resource:)` method, or _zip_ it and upload to a remote server, where it can be accessed via _http_.

That's pretty it! I would very appreciate your feedback and contribution.

P.S. Don't forget to check the [TwitterDemo](https://github.com/faviomob/WidgetKitSamples) - it provides "real world" example with much more sofisticated setup: you will learn how to make conditional actions, pull to refresh and infinite scroll, upload images, delete content respecting ownership and many other tricks, including integration with your custom code.

## License

MIT, Copyright (c) 2018 [Favio Mobile](http://favio.mobi)

## Contacts

You can reach me via faviomob@gmail.com