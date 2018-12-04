import UIKit

class AssetViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    private enum ReuseId {
        static let cell  = "snapshot"
        static let header = "header"
    }
    
    private let tableHeaderView = AssetTableHeaderView()
    private let loadMoreThreshold = 20
    
    private var asset: AssetItem!
    private var snapshotDataSource: SnapshotDataSource!
    
    private lazy var noTransactionFooterView = Bundle.main.loadNibNamed("NoTransactionFooterView", owner: self, options: nil)?.first as! UIView
    private lazy var filterWindow: AssetFilterWindow = {
        let window = AssetFilterWindow.instance()
        window.delegate = self
        return window
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layoutIfNeeded()
        updateTableViewContentInset()
        updateTableFooterView()
        tableHeaderView.filterButton.addTarget(self, action: #selector(presentFilterWindow(_:)), for: .touchUpInside)
        tableHeaderView.titleView.transferButton.addTarget(self, action: #selector(transfer(_:)), for: .touchUpInside)
        tableHeaderView.titleView.depositButton.addTarget(self, action: #selector(deposit(_:)), for: .touchUpInside)
        tableView.tableHeaderView = tableHeaderView
        tableHeaderView.titleView.render(asset: asset)
        tableHeaderView.sizeToFit()
        tableView.register(UINib(nibName: "SnapshotCell", bundle: .main), forCellReuseIdentifier: ReuseId.cell)
        tableView.register(AssetHeaderView.self, forHeaderFooterViewReuseIdentifier: ReuseId.header)
        tableView.dataSource = self
        tableView.delegate = self
        reloadAsset()
        snapshotDataSource.onReload = { [weak self] in
            guard let weakSelf = self else {
                return
            }
            weakSelf.tableView.reloadData()
            weakSelf.updateTableFooterView()
        }
        snapshotDataSource.reloadFromLocal()
        NotificationCenter.default.addObserver(self, selector: #selector(assetsDidChange(_:)), name: .AssetsDidChange, object: nil)
        ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(assetId: asset.assetId))
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewContentInset()
    }
    
    @objc func assetsDidChange(_ notification: Notification) {
        guard let assetId = notification.object as? String, assetId == asset.assetId else {
            return
        }
        reloadAsset()
    }
    
    @objc func presentFilterWindow(_ sender: Any) {
        filterWindow.presentPopupControllerAnimated()
    }
    
    @objc func transfer(_ sender: Any) {
        let vc = TransferPeerSelectionViewController.instance(asset: asset)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc func deposit(_ sender: Any) {
        guard !tableHeaderView.titleView.depositButton.isBusy else {
            return
        }
        let vc = DepositViewController.instance(asset: asset)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    class func instance(asset: AssetItem) -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "asset") as! AssetViewController
        vc.asset = asset
        vc.snapshotDataSource = SnapshotDataSource(category: .asset(id: asset.assetId))
        let container = ContainerViewController.instance(viewController: vc, title: asset.name)
        container.automaticallyAdjustsScrollViewInsets = false
        return container
    }
    
}

extension AssetViewController: ContainerViewControllerDelegate {
    
    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }
    
    func barRightButtonTappedAction() {
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let asset = self.asset!
        alc.addAction(UIAlertAction(title: Localized.WALLET_MENU_WITHDRAW, style: .default, handler: { [weak self] (_) in
            let vc = WithdrawalViewController.instance(asset: asset)
            self?.navigationController?.pushViewController(vc, animated: true)
        }))
        let toggleAssetHiddenTitle = WalletUserDefault.shared.hiddenAssets[asset.assetId] == nil ? Localized.WALLET_MENU_HIDE_ASSET : Localized.WALLET_MENU_SHOW_ASSET
        alc.addAction(UIAlertAction(title: toggleAssetHiddenTitle, style: .default, handler: { [weak self](_) in
            guard let weakSelf = self else {
                return
            }
            if WalletUserDefault.shared.hiddenAssets[asset.assetId] == nil {
                WalletUserDefault.shared.hiddenAssets[asset.assetId] = asset.assetId
            } else {
                WalletUserDefault.shared.hiddenAssets.removeValue(forKey: asset.assetId)
            }
            NotificationCenter.default.postOnMain(name: .AssetVisibleDidChange)
            weakSelf.navigationController?.popViewController(animated: true)
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
    }
    
    func imageBarRightButton() -> UIImage? {
        return #imageLiteral(resourceName: "ic_titlebar_more")
    }
    
}

extension AssetViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return snapshotDataSource.titles.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return snapshotDataSource.snapshots[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ReuseId.cell, for: indexPath) as! SnapshotCell
        cell.render(snapshot: snapshotDataSource.snapshots[indexPath.section][indexPath.row], asset: asset)
        cell.renderDecorationViews(indexPath: indexPath, models: snapshotDataSource.snapshots)
        cell.delegate = self
        return cell
    }
    
}

extension AssetViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let snapshot = snapshotDataSource.snapshots[indexPath.section][indexPath.row]
        if snapshot.type != SnapshotType.pendingDeposit.rawValue {
            let vc = TransactionViewController.instance(asset: asset, snapshot: snapshot)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.header) as! AssetHeaderView
        header.label.text = snapshotDataSource.titles[section]
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return PeerTransactionSnapshotCell.cellHeight
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let title = snapshotDataSource.titles[section]
        return title.isEmpty ? .leastNormalMagnitude : 32
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let distance = snapshotDataSource.distanceToLastItem(of: indexPath) else {
            return
        }
        if distance < loadMoreThreshold {
            snapshotDataSource.loadMoreIfPossible()
        }
    }
    
}

extension AssetViewController: AssetFilterWindowDelegate {
    
    func assetFilterWindow(_ window: AssetFilterWindow, didApplySort sort: Snapshot.Sort, filter: Snapshot.Filter) {
        tableView.setContentOffset(.zero, animated: false)
        tableView.layoutIfNeeded()
        snapshotDataSource.setSort(sort, filter: filter)
        updateTableFooterView()
    }
    
}

extension AssetViewController: SnapshotCellDelegate {
    
    func walletSnapshotCellDidSelectIcon(_ cell: SnapshotCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }
        guard let userId = snapshotDataSource.snapshots[indexPath.section][indexPath.row].opponentUserId else {
            return
        }
        DispatchQueue.global().async {
            guard let user = UserDAO.shared.getUser(userId: userId), user.identityNumber != "0" else {
                return
            }
            DispatchQueue.main.async {
                UserWindow.instance().updateUser(user: user).presentView()
            }
        }
    }
    
}

extension AssetViewController {
    
    private func updateTableViewContentInset() {
        if view.compatibleSafeAreaInsets.bottom < 1 {
            tableView.contentInset.bottom = 10
        } else {
            tableView.contentInset.bottom = 0
        }
    }
    
    private func reloadAsset() {
        let assetId = asset.assetId
        DispatchQueue.global().async { [weak self] in
            guard let asset = AssetDAO.shared.getAsset(assetId: assetId) else {
                return
            }
            self?.asset = asset
            DispatchQueue.main.sync {
                guard let weakSelf = self else {
                    return
                }
                UIView.performWithoutAnimation {
                    weakSelf.tableHeaderView.titleView.render(asset: asset)
                    weakSelf.updateTableFooterView()
                }
            }
        }
    }
    
    private func updateTableFooterView() {
        if snapshotDataSource.snapshots.isEmpty {
            tableHeaderView.transactionsHeaderView.isHidden = false
            noTransactionFooterView.frame.size.height = {
                if #available(iOS 11.0, *) {
                    return tableView.frame.height
                        - tableView.contentSize.height
                        - tableView.adjustedContentInset.vertical
                } else {
                    return tableView.frame.height
                        - tableView.contentSize.height
                        - tableView.contentInset.vertical
                }
            }()
            tableView.tableFooterView = noTransactionFooterView
        } else {
            tableHeaderView.transactionsHeaderView.isHidden = false
            tableView.tableFooterView = nil
        }
    }
    
}
