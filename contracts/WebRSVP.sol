// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract WebRSVP {

    event NewEventCreated (
        bytes32 eventID,
        address creatorAddress,
        uint256 eventTimestamp,
        uint256 maxCapacity,
        uint256 deposit, 
        string eventDataCID
    );

    event NewRSVP (bytes32 eventID, address attendeeAddress);

    event ConfirmedAttendee (bytes32 eventID, address attendeeAddress);

    event DepositsPaidOut (bytes32 eventID); 


    struct CreateEvent {
        bytes32 eventId;
        string eventDataCID;
        address eventOwner;
        uint256 eventTimeStamp;
        uint256 deposit;
        uint256 maxCapacity;
        address[] confirmedRSVPs;
        address[] claimedRSVPs;
        bool paidOut;
    }


    mapping (bytes32 => CreateEvent) public idToEvent;

    /** define the function createNewEvent and define the parameters the function should accept. 
    These are the settings-specific to an event that we will get 
    from the person actually creating the event on the frontend.*/ 

    function createNewEvent (
        uint256 eventTimestamp,
        uint256 deposit, 
        uint256 maxCapacity,
        string calldata eventDataCID 
        )  external {
            //generate an eventID based on other things passed in to generate hash
            
            bytes32 eventId = keccak256(
            abi.encodePacked(
                msg.sender,
                address(this),
                eventTimestamp,
                deposit,
                maxCapacity
            )
        );
        
        address[] memory confirmedRSVPs;
        address[] memory claimedRSVPs;

        // this creates a new CreateEvent struct and adds it to the idtoEvent mapping 
        idToEvent[eventId] = CreateEvent(
            eventId,
            eventDataCID,
            msg.sender,
            eventTimestamp,
            deposit,
            maxCapacity,
            confirmedRSVPs,
            claimedRSVPs,
            false
        ); 

        emit NewEventCreated(
            eventId, 
            msg.sender,
            eventTimestamp,
            maxCapacity,
            deposit,
            eventDataCID
        );

        }


        function createNewRSVP (bytes32 eventId) external payable {

            // look up event from our mapping
            CreateEvent storage myEvent = idToEvent [eventId];

             /** transfer deposit to our contract / require that they send enough
             ETH to cover the deposit requirement of this specific event */

            require(msg.value == myEvent.deposit, "NOT ENOUGH");

            //require that event has not already happened (<eventTimestamp)

            require(block.timestamp <= myEvent.eventTimestamp, "ALREADY HAPPENED");

            //make sure the event is under max capacity
            require (
                myEvent.confirmedRSVPs.length < myEvent.maxCapacity,
                "This event has reached capacity"
            );

            // require that msg.sender isn't already in myEvent.confirmedRSVPs AKA has not confirmed twice)
            for (uint8 i=0; i < myEvent.confirmedRSVPs.length; i++){
                require(myEvent.confirmedRSVPs[i] != msg.sender, "ALREADY CONFIRMED");
            }

            myEvent.confirmedRSVPs.push(payable(msg.sender));

            emit NewRSVP (eventId, msg.sender);

        } 



        function confirmAttendee (bytes32 eventId, address attendee) public {

            //look up event from our struct using the eventId
            CreateEvent storage myEvent = idToEvent[eventId];

            /** require that msg.sender is the owner of the event
            Only the host should be able to check people in 
             */

            require(msg.sender == myEvent.eventOwner, "NOT AUTHORIZED");

            //require that attendee trying to check in actually confirmed

            address rsvpConfirm;

            for (uint8 i=0; i < myEvent.confirmedRSVPs.length; i++){
                if(myEvent.confirmedRSVPs[i] == attendee){
                    rsvpConfirm = myEvent.confirmedRSVPs[i];
                }
            }

            require (rsvpConfirm == attendee, "NO RSVP TO CONFIRM");

            /** require that attendee is not already in the claimedRSVSPs list
            AKA make sure they have not already checked in  */

            for (uint8 i =0; i <myEvent.claimedRSVPs.length; i++){
                require(myEvent.claimedRSVPs[i] != attendee, "ALREADY CLAIMED");
            }

            //require that deposits are not already claimed by event owner
            require(myEvent.paidOut == false, "ALREADY PAID OUT");

            //add the attendee to the claimedRSVPs list 
            myEvent.claimedRSVPs.push(attendee);

            // sending ETH back to the staker `https://solidity-by-example.org/sending-ether`
            (bool sent,) = attendee.call{value: myEvent.deposit}("");

            //if this fails, remove the user from the array of claimed RSVPs
            if (!sent){
                myEvent.claimedRSVPs.pop();
            }

            require(sent, "Failed to send ETH");

            emit ConfirmedAttendee (eventId, attendee);

        }

        function confirmAllAttendees (bytes32 eventId) external {

            //look up event from our struct with eventId
            CreateEvent memory myEvent = idToEvent[eventId];

            //make sure you require that msg.sender is the owner of the event
            require(msg.sender == myEvent.eventOwner, "NOT AUTHORIZED");

            //confirm each attendee in the RSVP array
            for (uint8 i =0; i < myEvent.confirmedRSVPs.length; i++){
                confirmAttendee(eventId, myEvent.confirmedRSVPs[i]);
            }

        }

        function withdrawUnclaimedDeposits(bytes32 eventId) external {

            // look up event
            CreateEvent memory myEvent = idToEvent[eventId];

            //check that that paidout bool still equals false- AKA the money has not already been paid out
            require (!myEvent.paidOut, "ALREADY PAID OUT");

            // check if it has been 7 days past myEvent.eventTimeStamp
            require(
                block.timestamp >= (myEvent.eventTimeStamp + 7 days),
                "TOO EARLY"
            );

            //only the event owner can withdraw funds
            require(msg.sender == myEvent.eventOwner, "MUST BE EVENT OWNER");

            //Calculate how many people did not claim by comparing
            uint256 unclaimed = myEvent.confirmedRSVPs.length - myEvent.claimedRSVPs.length;

            uint256 payout = unclaimed * myEvent.deposit; 

            //mark as paid before send to avoid rentryancy attack
            myEvent.paidOut == true;

            //send the payout to the owner
            (bool sent, ) = msg.sender.call { value: payout}("");

            //if this fails 
            if (!sent) {
                myEvent.paidOut = false;
            }

            require (sent, "FAILED TO SEND ETH");

            emit DepositsPaidOut(eventId); 

        }

















        
        

}