import UIKit

class ShadowedCardView: UIView {
    
    private let cardLayer = CAShapeLayer()
    private let cornerRadius: CGFloat = 8
    private let shadowColor = UIColor(rgbValue: 0xC3C3C3)
    private let shadowOffset = CGPoint(x: 0, y: 5)
    
    private var lastBounds = CGRect.zero
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateCardPath()
    }
    
    private func prepare() {
        updateCardPath()
        cardLayer.fillColor = UIColor.white.cgColor
        cardLayer.shadowColor = shadowColor.cgColor
        cardLayer.shadowOpacity = 0.2
        cardLayer.shadowRadius = 8
        layer.insertSublayer(cardLayer, at: 0)
    }
    
    private func updateCardPath() {
        guard bounds != lastBounds else {
            return
        }
        cardLayer.path = CGPath(roundedRect: bounds,
                                cornerWidth: cornerRadius,
                                cornerHeight: cornerRadius,
                                transform: nil)
        let shadowRect = CGRect(origin: shadowOffset, size: bounds.size)
        cardLayer.shadowPath = CGPath(roundedRect: shadowRect,
                                      cornerWidth: cornerRadius,
                                      cornerHeight: cornerRadius,
                                      transform: nil)
        lastBounds = bounds
    }
    
}
