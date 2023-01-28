//
//  ViewController.swift
//  ExampleApp-PhotoApp
//
//  Created by Yuriy Gudimov on 28.01.2023.
//

import UIKit
import Photos
import Combine

struct AssetImage: Identifiable, Equatable, Hashable {
    let asset: PHAsset
    let image: UIImage
    
    var id: String {
        asset.localIdentifier
    }
}

class ViewController: UICollectionViewController {
    
    private var cancellables: Set<AnyCancellable> = []
    
    convenience init() {
        let layout = UICollectionViewCompositionalLayout(sectionProvider: { (section, env) -> NSCollectionLayoutSection? in
            let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1/3), heightDimension: .fractionalHeight(1)))
            item.contentInsets = .init(top: 2, leading: 2, bottom: 2, trailing: 2)
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .fractionalWidth(1/3)), subitems: [item])
            return NSCollectionLayoutSection(group: group)
        })
        self.init(collectionViewLayout: layout)
    }
    
    enum Section: Int {
        case photos
    }
    
    var diffableDatasource: UICollectionViewDiffableDataSource<Section, AssetImage>!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Photos"
        
        let cellRegistry = UICollectionView.CellRegistration<PhotoCell, AssetImage> { (cell, indexPath, assetImage) in
            cell.imageView.image = assetImage.image
        }
        
        diffableDatasource = UICollectionViewDiffableDataSource(collectionView: collectionView, cellProvider: { (cv, indexPath, assetImage) -> UICollectionViewCell? in
            cv.dequeueConfiguredReusableCell(using: cellRegistry, for: indexPath, item: assetImage)
        })
        
        PHPhotoLibrary.authorizationStatusPublisher(for: .readWrite)
            .filter { $0 == .authorized }
            .sink { [unowned self]_ in
                loadAssets()
            }
            .store(in: &cancellables)
    }
    
    private func loadAssets() {
        let size = CGSize(width: 600, height: 600)
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true

        PHAsset.fetchAssets(with: nil)
            .publisher
            .flatMap(maxPublishers: .max(3)) { asset in
                PHImageManager.default().publisher(for: asset, targetSize: size, contentMode: .aspectFill, options: requestOptions)
                    .replaceError(with: UIImage())
                    .map { AssetImage(asset: asset, image: $0) }
            }
            .collect()
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] images in
                update(with: images)
            }
            .store(in: &cancellables)
    }
    
    private func update(with images: [AssetImage]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, AssetImage>()
        snapshot.appendSections([.photos])
        snapshot.appendItems(images)
        diffableDatasource.apply(snapshot, animatingDifferences: true)
    }
}
