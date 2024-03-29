# UberSegmentedControl

<img align="right" src="Animations/UberSegmentedControl-Demo.gif?raw=true" alt="UberSegmentedControl Demo" width="300" height="300" />

A control inspired by Apple's `UISegmentedControl` that allows single, multiple and momentary selections and can display segments containing: only a title, only an image, or both at the same time.

## Features

- Allows single, multiple and momentary selections
- Segments may display titles, images or both at the same time
- Supports both light and dark appearance (only iOS / iPadOS 13+)

## Requirements

- iOS 9.0+ / iPadOS 13+
- Xcode 11+
- Swift 4.2+

<br clear="right"/>

## Installation

Install it as a dependency of your Xcode project using [Swift Package Manager](https://swift.org/package-manager/).

## Usage

```swift
let observers = NSMapTable<UberSegmentedControl, NSKeyValueObservation>(keyOptions: .weakMemory,
                                                                        valueOptions: .strongMemory)

override func loadView() {
  let items = ["Bold", "Italics", "Underline"]

  let uberSC = UberSegmentedControl(items: items, config: Config(allowsMultipleSelection: true))

  // Toggle segments 0 and 2 on
  uberSC.selectedSegmentIndexes = IndexSet([0, 2])

  // Disable segment 1
  uberSC.setEnabled(false, forSegmentAt: 1)

  // Handle value changes
  uberSC.addTarget(self, action: #selector(uberSCChanged), for: .valueChanged)
  
  // Alternatively, observe changes on `selectedSegmentIndexes`.
  observers.setObject(uberSC.observe(\.selectedSegmentIndexes, options: [.new, .old]) { (control, change) in
      if let oldIndexes = change.oldValue, let newIndexes = change.newValue {
          print("oldIndexes: \(Array(oldIndexes)), newIndexes: \(Array(newIndexes))")
      }
  }, forKey: uberSC)
  
  view.addSubview(uberSC)
}

override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    observers.removeAllObjects()
}

@objc func uberSCChanged(_ sender: UberSegmentedControl) {
    print("selectedSegmentIndexes: \(Array(sender.selectedSegmentIndexes))")
}
```

## Notes

See `TestPlayground.playground` for a full working example (requires Xcode 12+.)

## License

UberSegmentedControl is released under the MIT license. See [LICENSE](LICENSE) for details.
