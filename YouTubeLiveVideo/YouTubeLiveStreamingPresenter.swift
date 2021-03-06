//
//  YouTubeLiveStreamingPresenter.swift
//  YouTubeLiveVideo
//
//  Created by Sergey Krotkih on 10/24/16.
//  Copyright © 2016 Sergey Krotkih. All rights reserved.
//

import UIKit

class YouTubeLiveStreamingPresenter: NSObject {
   
   private var timer: NSTimer?
   private var livestreamId: String?
   
   private var liveBroadcast: LiveBroadcastStreamModel?
   private var liveStream: LiveStreamModel?
   
   private var isLiveVideo: Bool = false
   
   var youTubeRequest: YouTubeLiveStreamingRequest!
   var viewController: UIViewController!

   private var liveViewController: VideoStreamViewController!
}

// MARK: Live stream publishing

extension YouTubeLiveStreamingPresenter: VideoStreamViewControllerDelegate {
   
   func showVideoStreamViewController(liveStream: LiveStreamModel, liveBroadcast: LiveBroadcastStreamModel, completed: () -> Void) {
      self.liveBroadcast = liveBroadcast
      self.liveStream = liveStream
      
      let streamName = liveStream.cdn.ingestionInfo.streamName
      let streamUrl = liveStream.cdn.ingestionInfo.ingestionAddress
      let scheduledStartTime = liveBroadcast.snipped.scheduledStartTime
      
      let sreamId = liveStream.id
      let monitorStream = liveBroadcast.contentDetails.monitorStream.embedHtml
      let streamTitle = liveStream.snipped.title
      
      print("\n-BroadcastId=\(liveBroadcast.id);\n-Live stream id=\(sreamId); \n-title=\(streamTitle); \n-start=\(scheduledStartTime); \n-STREAM_URL=\(streamUrl)/STREAM_NAME=\(streamName): created!\n-MONITOR_STREAM=\(monitorStream)\n")
      print("Watch the live video: https://www.youtube.com/watch?v=\(liveBroadcast.id)")
      
      self.liveViewController = VideoStreamViewController()
      self.liveViewController.delegate = self
      self.liveViewController.scheduledStartTime = scheduledStartTime
      self.liveViewController.livebroadcast = liveBroadcast
      
      Preference.defaultInstance.uri = streamUrl
      Preference.defaultInstance.streamName = streamName

      self.viewController.presentViewController(self.liveViewController, animated: false, completion: {
         completed()
      })
   }

   private func dismissVideoStreamViewController() {
      dispatch_async(dispatch_get_main_queue()) {
         self.viewController.dismissViewControllerAnimated(true, completion: {
         })
      }
   }
   
   func startPublishing(broadcast broadcast: LiveBroadcastStreamModel?, completed: (Bool) -> Void) {
      self.isLiveVideo = false
      self.startChekingStreamStatusTimer()
      completed(true)
   }
   
   func finishPublishing(broadcast broadcast: LiveBroadcastStreamModel?, completed: (Bool) -> Void) {
      stopChekingStreamStatusTimer()
      
      if let broadcast = broadcast {
         // complete – The broadcast is over. YouTube stops transmitting video.
         youTubeRequest.transitionLiveBroadcast(broadcast.id, broadcastStatus: "complete", completed: { liveBroadcast in
            if let _ = liveBroadcast {
               print("Broadcast completed!")
            }
            self.dismissVideoStreamViewController()
            completed(true)
         })
      } else {
         self.dismissVideoStreamViewController()
         completed(false)
      }
      completed(true)
   }
   
   func cancelPublishing(broadcast broadcast: LiveBroadcastStreamModel?, completed: (Bool) -> Void) {
      if broadcast == nil {
         self.dismissVideoStreamViewController()
      } else if let liveBroadcast = self.liveBroadcast {
         youTubeRequest.deleteLiveBroadcast(broadcastId: liveBroadcast.id, completed: { success in
            if success {
               print("Broadcast \"\(liveBroadcast.id)\" was deleted!")
            } else {
               Alert.sharedInstance.showOk("Sorry, system error while delete video", message: "You can try to do it in your YouTube account")
            }
            self.dismissVideoStreamViewController()
         })
      }
   }
   
   private func startChekingStreamStatusTimer() {

      let timerIntervalInSec = 5.0
      
      timer?.invalidate()
      timer = NSTimer(timeInterval: timerIntervalInSec, target: self, selector: #selector(requestBroadcastStatus), userInfo: nil, repeats: true)
      NSRunLoop.mainRunLoop().addTimer(timer!, forMode: NSRunLoopCommonModes)
      requestBroadcastStatus()
   }
   
   private func stopChekingStreamStatusTimer() {
      timer?.invalidate()
      timer = nil
   }
   
   func requestBroadcastStatus() {
      guard let liveBroadcast = self.liveBroadcast else {
         return
      }
      guard let liveStream = self.liveStream else {
         return
      }
      
      youTubeRequest.getLiveBroadcast(broadcastId: liveBroadcast.id, completed: { broadcast in
         if let broadcast = broadcast {
            let broadcastStatus = broadcast.status.lifeCycleStatus
            
//            Valid values for this property are:
//            abandoned – This broadcast was never started.
//            complete – The broadcast is finished.
//            created – The broadcast has incomplete settings, so it is not ready to transition to a live or testing status, but it has been created and is otherwise valid.
//            live – The broadcast is active.
//            liveStarting – The broadcast is in the process of transitioning to live status.
//            ready – The broadcast settings are complete and the broadcast can transition to a live or testing status.
//            reclaimed – This broadcast has been reclaimed.
//            revoked – This broadcast was removed by an admin action.
//            testStarting – The broadcast is in the process of transitioning to testing status.
//            testing – The broadcast is only visible to the partner.

            self.youTubeRequest.getLiveStream(liveStream.id, completed: { liveStream in
               if let liveStream = liveStream {
                  //            Valid values for this property are:
                  //            active – The stream is in active state which means the user is receiving data via the stream.
                  //            created – The stream has been created but does not have valid CDN settings.
                  //            error – An error condition exists on the stream.
                  //            inactive – The stream is in inactive state which means the user is not receiving data via the stream.
                  //            ready – The stream has valid CDN settings.
                  let status = liveStream.status.streamStatus
                  
                  //            Valid values for this property are:
                  //            good – There are no configuration issues for which the severity is warning or worse.
                  //            ok – There are no configuration issues for which the severity is error.
                  //            bad – The stream has some issues for which the severity is error.
                  //            noData – YouTube's live streaming backend servers do not have any information about the stream's health status.
                  let healthStatus = liveStream.status.healthStatus.status
                  
                  if broadcastStatus == "live" || broadcastStatus == "liveStarting" {
                     self.liveViewController.showCurrentStatus("● LIVE   ")
                  } else {
                     let text = "status: \(broadcastStatus) [\(status);\(healthStatus)]"
                     self.liveViewController.showCurrentStatus(text)
                     self.transitionBroadcastToStatus("live", completed: { inLive in
                        if inLive {
                           print("Transition to the LIVE status was made successfully")
                           self.isLiveVideo = true
                        } else {
                           print("Failed transition to the LIVE status!")
                           self.isLiveVideo = false
                           self.transitionBroadcastToStatus("testing", completed: { inTesting in
                           })
                        }
                     })
                  }
               }
            })
         }
      })
   }

   private func transitionBroadcastToStatus(status: String, completed: (Bool) -> Void) {
      if let liveBroadcast = self.liveBroadcast {
         // complete – The broadcast is over. YouTube stops transmitting video.
         // live – The broadcast is visible to its audience. YouTube transmits video to the broadcast's monitor stream and its broadcast stream.
         // testing – Start testing the broadcast. YouTube transmits video to the broadcast's monitor stream.
         youTubeRequest.transitionLiveBroadcast(liveBroadcast.id, broadcastStatus: status, completed: { liveBroadcast in
            if let _ = liveBroadcast {
               completed(true)
               print("Our broadcast in the LIVE status!")
            } else {
               completed(false)
            }
         })
      } else {
         completed(false)
      }
   }
}
