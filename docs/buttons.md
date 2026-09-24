#Roll Button

#This command will roll for the user. Uses function AG_OnClickROLL

			<Button name="AG_ROLL_Button" inherits="OptionsButtonTemplate" movable="true" text="ROLL!">
				<Anchors>
					<Anchor point="BOTTOM">
						<Offset x="-105" y="35" />
					</Anchor>
				</Anchors>
				<Scripts>
					<OnClick>
						AG_OnClickROLL();
					</OnClick>
				</Scripts>
			</Button>

			
#Entry button

#This button will notify users the game has begun and entries are now accepted. Should also announce game mode and wager.
#Button click executes AG_OnClickEntry

			<Button name="AG_Entry_Button" inherits="OptionsButtonTemplate" text="Entries">
				<Anchors>
					<Anchor point="BOTTOM">
						<Offset x="-105" y="75" />
					</Anchor>
				</Anchors>
				<Scripts>
					<OnClick>
						AG_OnClickEntry();

					</OnClick>
				</Scripts>
			</Button>
			
	
#Last call button

#This button will shout 'Last call!' and then after 10 seconds, inform everyone that entries are closed and they can ROLL! 
#Clicking this button executes AG_OnClickLASTCALL

 			<Button name="AG_LASTCALL_Button" inherits="OptionsButtonTemplate" movable="true" text="Last Call">
				<Anchors>
					<Anchor point="BOTTOM">
						<Offset x="-105" y="55" />
					</Anchor>
				</Anchors>
				<Scripts>
					<OnClick>
						AG_OnClickLASTCALL();
					</OnClick>
				</Scripts>
			</Button>
			
#X for the top right Corner?
			<Button name="AG_Close" inherits="UIPanelCloseButton">
				<Anchors>
					<Anchor point="TOPRIGHT" relativeTo="AG_Frame" relativePoint="TOPRIGHT">
						<Offset>
							<AbsDimension x="7" y="6"/>
						</Offset>
					</Anchor>
				</Anchors>
			</Button>		

#Stats Button

#This button will post the highest and lowest scores in chat, using command AG_OnClickSTATS	

<Button name="AG_STATS_Button" inherits="OptionsButtonTemplate" movable="true" text="Stats">
				<Anchors>
					<Anchor point="BOTTOM">
						<Offset x="105" y="35" />
					</Anchor>
				</Anchors>
				<Scripts>
					<OnClick>
						AG_OnClickSTATS();
					</OnClick>
				<OnLoad>AG_STATS_Button.tooltipText="Show's all user stats."</OnLoad>
				</Scripts>
			</Button>
			