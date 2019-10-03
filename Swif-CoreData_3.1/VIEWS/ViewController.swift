//
//  ViewController.swift
//  Swif-CoreData_3.1
//
//  Created by Maurice on 10/1/19.
//  Copyright © 2019 maurice. All rights reserved.
//

import UIKit
import CoreData

class ViewController: UITableViewController {

	var commits = [Commit]()
    var container: NSPersistentContainer!
    var commitPredicate: NSPredicate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
		self.title = "Listing All Commits"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Filter", style: .plain, target: self, action: #selector(changeFilter))
        
        // initializing the persistent containter
        container = NSPersistentContainer(name: "Project38")
        
        container.loadPersistentStores { storeDescription, error in
            self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
            if let error = error {
                print("Unresolved error \(error)")
            }
        }
        
		performSelector(inBackground: #selector(fetchCommits), with: nil)
		loadSavedData()
        
        // get the app dir
        //applicationDocumentsDirectory()
    }
	
	
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return commits.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Commit", for: indexPath)
		
		let commit = commits[indexPath.row]
		cell.textLabel!.text = commit.message
		cell.detailTextLabel!.text = commit.date.description
		
		return cell
	}
	
	func loadSavedData() {
		let request = Commit.createFetchRequest()
		let sort = NSSortDescriptor(key: "date", ascending: false)
		request.sortDescriptors = [sort]
        request.predicate = commitPredicate

		do {
			commits = try container.viewContext.fetch(request)
			print("Got \(commits.count) commits")
			tableView.reloadData()
		} catch {
			print("Fetch failed")
		}
	}
    
    func saveContext() {
        if container.viewContext.hasChanges {
            do {
                try container.viewContext.save()
            } catch {
                print("An error occurred while saving: \(error)")
            }
        }
    }
	
	@objc func fetchCommits() {
        let apiUrl = "ttps://api.github.com/repos/apple/swift/commits?per_page=100"
		if let data = try? String(contentsOf: URL(string: apiUrl)!) {
			// give the data to SwiftyJSON to parse
			let jsonCommits = JSON(parseJSON: data)
			
			// read the commits back out
			let jsonCommitArray = jsonCommits.arrayValue
			
			print("Received \(jsonCommitArray.count) new commits.")
			
			DispatchQueue.main.async { [unowned self] in
				for jsonCommit in jsonCommitArray {
					// the following three lines are new
					let commit = Commit(context: self.container.viewContext)
					self.configure(commit: commit, usingJSON: jsonCommit)
				}
				
				self.saveContext()
				self.loadSavedData()
			}
		}
	}
	
	func configure(commit: Commit, usingJSON json: JSON) {
		commit.sha = json["sha"].stringValue
		commit.message = json["commit"]["message"].stringValue
		commit.url = json["html_url"].stringValue
		
		let formatter = ISO8601DateFormatter()
		commit.date = formatter.date(from: json["commit"]["committer"]["date"].stringValue) ?? Date()
	}
    
    //commits filter function
    @objc func changeFilter (){
    let ac = UIAlertController(title: "Filter commits…", message: nil, preferredStyle: .actionSheet)
    
    ac.addAction(UIAlertAction(title: "Show only fixes", style: .default) { [unowned self] _ in
        self.commitPredicate = NSPredicate(format: "message CONTAINS[c] 'fix'")
        self.loadSavedData()
        self.title = " Show Only fixes"
    })
    ac.addAction(UIAlertAction(title: "Ignore Pull Requests", style: .default) { [unowned self] _ in
        self.commitPredicate = NSPredicate(format: "NOT message BEGINSWITH 'Merge pull request'")
        self.title = "Ignored PullRequests"
        self.loadSavedData()
    })
    ac.addAction(UIAlertAction(title: "Show only recent", style: .default) { [unowned self] _ in
        let twelveHoursAgo = Date().addingTimeInterval(-43200)
        self.commitPredicate = NSPredicate(format: "date > %@", twelveHoursAgo as NSDate)
        self.title = "Recent Commits"
        self.loadSavedData()
    })
    ac.addAction(UIAlertAction(title: "Show all commits", style: .default) { [unowned self] _ in
        self.commitPredicate = nil
        self.loadSavedData()
    })
    ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    present(ac, animated: true)
    }

    // getting the file path of the sqlite file
    func applicationDocumentsDirectory() {
        if let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).last {
            print(url.absoluteString)
        }
    }
    
}

