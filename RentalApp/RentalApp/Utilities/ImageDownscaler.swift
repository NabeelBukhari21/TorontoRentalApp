//
//  ImageDownscaler.swift
//  RentalApp (Purrperty)
//
//  Utilities — Shrinks a photo to upload size.
//
//  A 48 MP iPhone photo is 10+ MB; nobody needs that to see a leak under
//  a sink. Photos are resized to a 1600 px long edge and re-encoded as
//  JPEG before they're attached, off the main actor.
//

import UIKit

enum ImageDownscaler {

    /// Long edge in pixels. Enough to zoom into a photo of a part number.
    static let maxPixelLength: CGFloat = 1600

    /// Downscaled JPEG data, or nil when `data` isn't an image.
    @concurrent
    static func jpeg(from data: Data, quality: CGFloat = 0.75) async -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let longEdge = max(image.size.width, image.size.height) * image.scale
        guard longEdge > maxPixelLength else {
            return image.jpegData(compressionQuality: quality)
        }

        let ratio = maxPixelLength / longEdge
        let target = CGSize(
            width: (image.size.width * image.scale * ratio).rounded(),
            height: (image.size.height * image.scale * ratio).rounded()
        )
        let resized = await image.byPreparingThumbnail(ofSize: target) ?? image
        return resized.jpegData(compressionQuality: quality)
    }
}
