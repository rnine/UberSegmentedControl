//
//  UberSegmentedControl.swift
//
//
//  Created by Ruben Nine on 14/07/2020.
//

import UIKit

/// A control made of multiple segments, each segment functioning as a discrete button with support for single or
/// multiple selection mode.
open class UberSegmentedControl: UIControl {
    // MARK: - Public Properties

    /// Whether this segmented control allows multiple selection.
    public let allowsMultipleSelection: Bool

    /// Returns the number of segments the receiver has.
    open var numberOfSegments: Int { segmentsStackView.arrangedSubviews.count }

    /// The natural size for the control.
    open override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Constants.Measure.segmentHeight)
    }

    // MARK: - Private Properties

    private var segments: [SegmentButton] { segmentsStackView.arrangedSubviews.compactMap { $0 as? SegmentButton } }
    private var selectionButton: SegmentButton?
    private lazy var gestureHandler = StackViewGestureHandler(stackView: segmentsStackView)

    private let panGestureRecognizer = UIPanGestureRecognizer()
    private let buttonObservers = NSMapTable<SegmentButton, NSKeyValueObservation>(keyOptions: .weakMemory,
                                                                                   valueOptions: .strongMemory)

    private let dividersStackView: UIStackView = {
        let stackView = UIStackView()

        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.layoutMargins = Constants.Margins.dividerInsets
        stackView.isLayoutMarginsRelativeArrangement = true

        return stackView
    }()

    private let segmentsStackView: UIStackView = {
        let stackView = UIStackView()

        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = Constants.Measure.spacingBetweenSegments
        stackView.layoutMargins = Constants.Margins.segmentInsets
        stackView.isLayoutMarginsRelativeArrangement = true

        return stackView
    }()

    // MARK: - Lifecycle

    /// Initializes and returns a segmented control with segments having the given titles or images.
    ///
    /// - Parameter items: An array of NSString objects (for segment titles) or UIImage objects (for segment images).
    /// - Parameter allowsMultipleSelection: Whether this segmented control allows multiple selection.
    public init(items: [Any]?, allowsMultipleSelection: Bool = false) {
        self.allowsMultipleSelection = allowsMultipleSelection

        super.init(frame: .zero)

        setup()

        if let items = items {
            for (idx, item) in items.enumerated() {
                switch item {
                case let title as String:
                    insertSegment(withTitle: title, at: idx, animated: false)
                case let image as UIImage:
                    insertSegment(with: image, at: idx, animated: false)
                default:
                    break
                }
            }
        }
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - View Overrides

extension UberSegmentedControl {
    open override func layoutSubviews() {
        super.layoutSubviews()

        if !allowsMultipleSelection {
            // Ensure `selectionButton` is setup when single selection mode is used and a segment is selected.
            if selectionButton == nil, let segmentIndex = selectedSegmentIndexes.first {
                let segment = segments[segmentIndex]

                if segment.isSelected {
                    updateSelectionButton(using: segment)
                }
            }
        }
    }

    open override func didMoveToSuperview() {
        super.didMoveToSuperview()

        if !allowsMultipleSelection {
            buttonObservers.removeAllObjects()

            // Keep `isHighlighted` state synchronized between `selectionButton` and `button` when using
            // single selection mode.
            for segment in segments {
                buttonObservers.setObject(segment.observe(\.isHighlighted, changeHandler: { (button, change) in
                    if self.selectionButton?.center == button.center {
                        self.selectionButton?.isHighlighted = button.isHighlighted
                    }
                }), forKey: segment)
            }
        }
    }

    open override func removeFromSuperview() {
        super.removeFromSuperview()

        buttonObservers.removeAllObjects()
    }
}

// MARK: - Open Functions and Properties

extension UberSegmentedControl {
    /// Inserts a segment at a specific position in the receiver and gives it a title as content.
    ///
    /// - Parameter title: A string to use as the segment’s title.
    /// - Parameter segment: An index number identifying a segment in the control.
    /// - Parameter animated: true if the insertion of the new segment should be animated, otherwise false.
    open func insertSegment(withTitle title: String?, at segment: Int, animated: Bool) {
        let button = SegmentButton()

        button.setTitle(title, for: .normal)
        button.accessibilityLabel = title

        insertSegment(withButton: button, at: segment, animated: animated)
    }

    /// Inserts a segment at a specified position in the receiver and gives it an image as content.
    ///
    /// - Parameter image: An image object to use as the content of the segment.
    /// - Parameter segment: An index number identifying a segment in the control.
    /// - Parameter animated: true if the insertion of the new segment should be animated, otherwise false.
    open func insertSegment(with image: UIImage?, at segment: Int, animated: Bool) {
        let button = SegmentButton()

        button.setImage(image?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.setImage(image?.withRenderingMode(.alwaysTemplate), for: .highlighted)

        insertSegment(withButton: button, at: segment, animated: animated)
    }

    /// Removes the specified segment from the receiver, optionally animating the transition.
    ///
    /// - Parameter segment: An index number identifying a segment in the control.
    /// - Parameter animated: true if the removal of the segment should be animated, otherwise false.
    open func removeSegment(at segment: Int, animated: Bool) {
        guard segment < segmentsStackView.arrangedSubviews.count else { return }

        let view = segmentsStackView.arrangedSubviews[segment]

        if let view = dividersStackView.arrangedSubviews.last {
            view.removeFromSuperview()
            dividersStackView.removeArrangedSubview(view)
        }

        let onCompletion: () -> () = {
            view.removeFromSuperview()
            self.segmentsStackView.removeArrangedSubview(view)
        }

        if animated {
            UIView.animate(withDuration: Constants.Duration.regular) {
                view.isHidden = true
            } completion: { _ in onCompletion() }
        } else {
            onCompletion()
        }
    }

    /// Removes all segments of the receiver.
    open func removeAllSegments() {
        while numberOfSegments > 0 {
            removeSegment(at: numberOfSegments - 1, animated: false)
        }
    }

    /// Sets the title of a segment.
    ///
    /// - Parameter title: A string to display in the segment as its title.
    /// - Parameter segment: An index number identifying a segment in the control.
    open func setTitle(_ title: String?, forSegmentAt segment: Int) {
        guard segment < segments.count else { return }

        let button = segments[segment]

        button.setTitle(title, for: .normal)
        button.accessibilityLabel = title

        updateSegmentInsets(segment: button)
    }

    /// Returns the title of the specified segment.
    ///
    /// - Parameter segment: An index number identifying a segment in the control.
    open func titleForSegment(at segment: Int) -> String? {
        guard segment < segments.count else { return nil }

        return segments[segment].title(for: .normal)
    }

    /// Sets the content of a segment to a given image.
    ///
    /// - Parameter image: An image object to display in the segment.
    /// - Parameter segment: An index number identifying a segment in the control.
    open func setImage(_ image: UIImage?, forSegmentAt segment: Int) {
        guard segment < segments.count else { return }

        let button = segments[segment]

        button.setImage(image, for: .normal)

        updateSegmentInsets(segment: button)
    }

    /// Returns the image for a specific segment.
    ///
    /// - Parameter segment: An index number identifying a segment in the control.
    open func imageForSegment(at segment: Int) -> UIImage? {
        guard segment < segments.count else { return nil }

        return segments[segment].image(for: .normal)
    }

    /// Enables the specified segment.
    ///
    /// - Parameter enabled: true to enable the specified segment or false to disable the segment. By default,
    /// segments are enabled.
    /// - Parameter segment: An index number identifying a segment in the control.
    open func setEnabled(_ enabled: Bool, forSegmentAt segment: Int) {
        guard segment < segments.count else { return }

        segments[segment].isEnabled = enabled
    }

    /// Returns whether the indicated segment is enabled.
    ///
    /// - Parameter segment: An index number identifying a segment in the control.
    open func isEnabledForSegment(at segment: Int) -> Bool {
        guard segment < segments.count else { return false }

        return segments[segment].isEnabled
    }

    /// The color to use for highlighting the currently selected segment.
    open var selectedSegmentTintColor: UIColor? {
        return Constants.Color.selectedSegmentTint
    }

    /// Indexes of selected segments (can be more than one if `allowsMultipleSelection` is `true`.)
    @objc open var selectedSegmentIndexes: IndexSet {
        get { IndexSet(segments.enumerated().filter { $1.isSelected }.map { $0.offset }) }

        set {
            var shouldDeselectOtherSegments = false

            for (i, segment) in segments.enumerated() {
                if shouldDeselectOtherSegments {
                    segment.isSelected = false
                } else {
                    segment.isSelected = newValue.contains(i)
                }

                if !allowsMultipleSelection, segment.isSelected {
                    shouldDeselectOtherSegments = true
                    updateSelectionButton(using: segment)
                }
            }

            updateDividers()
        }
    }
}

// MARK: - Private Functions

private extension UberSegmentedControl {
    func updateSegmentInsets(segment: SegmentButton) {
        if segment.currentImage != nil, segment.currentTitle != nil {
            segment.titleEdgeInsets = Constants.Margins.titleEdgeInsets
        } else {
            segment.titleEdgeInsets = .zero
        }

        segment.contentEdgeInsets = suggestedContentEdgeInsetsForSegment(segment: segment)
    }

    func suggestedContentEdgeInsetsForSegment(segment: SegmentButton) -> UIEdgeInsets {
        if segment.currentTitle != nil, segment.currentImage != nil {
            var insets = Constants.Margins.segmentContentEdgeInsets

            insets.right = segment.titleEdgeInsets.left - (segment.titleEdgeInsets.right * 2)

            return insets
        } else {
            return Constants.Margins.segmentContentEdgeInsets
        }
    }

    func insertSegment(withButton button: SegmentButton, at segment: Int, animated: Bool) {
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

        button.translatesAutoresizingMaskIntoConstraints = false
        button.adjustsImageWhenHighlighted = false
        button.tintColor = Constants.Color.label
        button.setTitleColor(Constants.Color.label, for: .normal)
        button.titleLabel?.font = Constants.Font.segmentTitleLabel

        updateSegmentInsets(segment: button)

        if allowsMultipleSelection {
            button.selectedBackgroundTintColor = selectedSegmentTintColor
        }

        if animated { button.isHidden = true }

        segmentsStackView.insertArrangedSubview(button, at: segment)
        dividersStackView.addArrangedSubview(DividerView())
        updateDividers()

        if animated { UIView.animate(withDuration: Constants.Duration.regular) { button.isHidden = false } }
    }

    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Constants.Color.background
        layer.cornerRadius = Constants.Measure.cornerRadius

        if intrinsicContentSize.height != UIView.noIntrinsicMetric {
            heightAnchor.constraint(equalToConstant: intrinsicContentSize.height).isActive = true
        }

        if intrinsicContentSize.width != UIView.noIntrinsicMetric {
            widthAnchor.constraint(equalToConstant: intrinsicContentSize.width).isActive = true
        }

        fill(with: dividersStackView, shouldAutoActivate: true)
        fill(with: segmentsStackView, shouldAutoActivate: true)

        panGestureRecognizer.delegate = self
        panGestureRecognizer.addTarget(self, action: #selector(handlePanGesture(recognizer:)))

        addGestureRecognizer(panGestureRecognizer)
    }

    func updateDividers() {
        let buttons = self.segments

        for (idx, separator) in dividersStackView.arrangedSubviews.enumerated() {
            var nextButton: UIButton?

            if let nextIndex = idx < max(0, segmentsStackView.arrangedSubviews.endIndex - 1) ? idx + 1 : nil {
                nextButton = segmentsStackView.arrangedSubviews[nextIndex] as? UIButton
            }

            if separator == dividersStackView.arrangedSubviews.last {
                separator.alpha = 0
            } else if buttons[idx].isSelected || nextButton?.isSelected == true {
                separator.alpha = 0
            } else {
                separator.alpha = 1
            }
        }
    }

    func handleMultipleSelectionButtonTap(using button: UIButton) {
        button.isSelected = !button.isSelected

        for segment in segments {
            segment.isHighlighted = button == segment
        }
    }

    func handleSingleSelectionButtonTap(using button: UIButton) {
        updateSelectionButton(using: button)

        for segment in segments {
            if button == segment {
                segment.isSelected = true
                segment.isHighlighted = true
            } else {
                segment.isSelected = false
                segment.isHighlighted = false
            }
        }
    }

    func updateSelectionButton(using button: UIButton) {
        if button.bounds.size == .zero {
            // Layout segment subviews
            segmentsStackView.layoutSubviews()
        }

        // Ensure button has a size.
        guard button.bounds.size != .zero else { return }

        if selectionButton == nil {
            UIView.setAnimationsEnabled(false)

            let selectionButton = SegmentButton()

            selectionButton.isUserInteractionEnabled = false
            selectionButton.selectedBackgroundTintColor = selectedSegmentTintColor
            selectionButton.isSelected = true
            selectionButton.center = button.center
            selectionButton.bounds = button.bounds
            selectionButton.alpha = 0

            insertSubview(selectionButton, belowSubview: segmentsStackView)

            UIView.setAnimationsEnabled(true)

            self.selectionButton = selectionButton
        }

        selectionButton?.center = button.center
        selectionButton?.bounds = button.bounds
        selectionButton?.alpha = 1
    }
}

// MARK: - Button Actions

extension UberSegmentedControl {
    @objc func buttonTapped(_ button: UIButton) {
        guard button.isEnabled else { return }
        
        willChangeValue(for: \.selectedSegmentIndexes)

        if allowsMultipleSelection {
            UIView.animate(withDuration: Constants.Duration.snappy) {
                self.handleMultipleSelectionButtonTap(using: button)
            }
        } else {
            UIView.animate(withDuration: Constants.Duration.regular,
                           delay: 0,
                           usingSpringWithDamping: 0.85,
                           initialSpringVelocity: 0.1,
                           options: .curveEaseOut) {
                self.handleSingleSelectionButtonTap(using: button)
            } completion: { _ in /* NO-OP */ }
        }
        
        didChangeValue(for: \.selectedSegmentIndexes)

        sendActions(for: .valueChanged)

        UIView.animate(withDuration: Constants.Duration.regular) {
            self.updateDividers()
        }
    }
}

// MARK: - UIGestureRecognizerDelegate Conformance

extension UberSegmentedControl: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool {
        return true
    }
}

// MARK: - Gesture Recognizer Actions

extension UberSegmentedControl {
    @objc func handlePanGesture(recognizer: UIPanGestureRecognizer) {
        if let button = gestureHandler.handle(recognizer: recognizer) as? UIButton {
            buttonTapped(button)
        }

        switch recognizer.state {
        case .ended, .cancelled, .failed:
            for button in segments {
                button.isHighlighted = false
            }
        default:
            break
        }
    }
}
