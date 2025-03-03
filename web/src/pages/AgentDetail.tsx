import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Layout } from '../components/Layout';
import { useNetworkVariable } from '../hooks/useNetworkVariable';
import { useRoochClient, useRoochClientQuery, useCurrentWallet, useCurrentSession, SessionKeyGuard } from '@roochnetwork/rooch-sdk-kit';
import { Agent, Character, Memory } from '../types/agent';
import { Args, isValidAddress, bcs, Transaction } from '@roochnetwork/rooch-sdk';
import { MemoryBrowser } from '../components/MemoryBrowser';
import { MemorySchema } from '../types/agent';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { oneLight } from 'react-syntax-highlighter/dist/esm/styles/prism';
import { shortenAddress } from '../utils/address';

export function AgentDetail() {
  const { agentId } = useParams<{ agentId: string }>();
  const [agent, setAgent] = useState<Agent | null>(null);
  const [character, setCharacter] = useState<Character | null>(null);
  const [homeChannelId, setHomeChannelId] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isHomeChannelLoading, setIsHomeChannelLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'details' | 'memories'>('details');
  const [isUserAuthorized, setIsUserAuthorized] = useState(false);
  const [agentCaps, setAgentCaps] = useState<{id: string, agentId: string}[]>([]);
  
  // Add state for inline editing
  const [isEditingDescription, setIsEditingDescription] = useState(false);
  const [isEditingName, setIsEditingName] = useState(false);
  const [editName, setEditName] = useState('');
  const [editDescription, setEditDescription] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const [updateError, setUpdateError] = useState<string | null>(null);
  const [updateSuccess, setUpdateSuccess] = useState(false);
  
  const navigate = useNavigate();
  const packageId = useNetworkVariable('packageId');
  const client = useRoochClient();
  const wallet = useCurrentWallet();
  const session = useCurrentSession();

  //TODO use the scanUrl via the network.
  const roochscanBaseUrl = "https://test.roochscan.io"
  
  // Add these state variables for memories tab
  const [selfMemories, setSelfMemories] = useState<Memory[]>([]);
  const [userMemories, setUserMemories] = useState<Memory[]>([]);
  const [isLoadingSelfMemories, setIsLoadingSelfMemories] = useState(false);
  const [isLoadingUserMemories, setIsLoadingUserMemories] = useState(false);
  const [searchAddress, setSearchAddress] = useState<string>("");
  const [searchResults, setSearchResults] = useState<Memory[]>([]);
  const [isSearching, setIsSearching] = useState(false);

  // Query the specific agent by ID
  const { data: agentResponse, isLoading: isAgentLoading, error: agentError, refetch: refetchAgent } = useRoochClientQuery(
    'queryObjectStates',
    {
      filter: {
        object_id: agentId,
      },
    },
    {
      enabled: !!client && !!packageId && !!agentId,
    }
  );

  // Query home channel ID using executeViewFunction
  const { data: homeChannelResponse, isLoading: isHomeChannelQueryLoading } = useRoochClientQuery(
    'executeViewFunction',
    {
      target: `${packageId}::channel::get_agent_home_channel_id`,
      args: agentId ? [Args.objectId(agentId)] : [],
    },
    {
      enabled: !!client && !!packageId && !!agentId,
    }
  );

  // Query agent capabilities owned by the current user
  const { data: agentCapsResponse, isLoading: isAgentCapsLoading } = useRoochClientQuery(
    'queryObjectStates',
    {
      filter: {
        object_type_with_owner: {
          object_type: `${packageId}::agent_cap::AgentCap`,
          owner: wallet?.wallet?.getBitcoinAddress().toStr()
        }
      },
    },
    {
      enabled: !!client && !!packageId && !!wallet?.wallet,
    }
  );

  // Effect to check if user has authorization to edit this agent
  useEffect(() => {
    if (!agentId || !agentCapsResponse?.data || isAgentCapsLoading) return;
    
    try {
      const caps: {id: string, agentId: string}[] = [];
      
      agentCapsResponse.data.forEach(obj => {
        if (obj.decoded_value?.value?.agent_obj_id) {
          caps.push({
            id: obj.id,
            agentId: obj.decoded_value.value.agent_obj_id
          });
        }
      });
      
      setAgentCaps(caps);
      
      // Check if the current agent ID is in the list of authorized agents
      const hasAccess = caps.some(cap => cap.agentId === agentId);
      setIsUserAuthorized(hasAccess);
      
    } catch (error) {
      console.error('Error processing agent caps:', error);
    }
  }, [agentId, agentCapsResponse, isAgentCapsLoading]);

  // Effect to process agent data and fetch character
  useEffect(() => {
    if (isAgentLoading) {
      setIsLoading(true);
      return;
    }

    if (agentError) {
      console.error('Failed to fetch agent details:', agentError);
      setError('Failed to load agent details. Please try again.');
      setIsLoading(false);
      return;
    }

    const processAgentData = async () => {
      try {
        if (agentResponse?.data && agentResponse.data.length > 0) {
          
          // Get the first agent from the array
          const agentObj = agentResponse.data[0];
          const agentData = agentObj.decoded_value.value;
          
          // Get the character ID from the agent data
          const characterId = agentData.character?.value?.id;
          const agentAddress = agentData.agent_address;
          
          // Create the agent object
          const processedAgent: Agent = {
            id: agentObj.id,
            name: 'Loading...', // Will be updated when character is loaded
            agent_address: agentAddress,
            characterId: characterId,
            modelProvider: agentData.model_provider || 'Unknown',
            createdAt: parseInt(agentData.last_active_timestamp) || Date.now(),
          };
          
          setAgent(processedAgent);
          
          // If we have a character ID, fetch the character details
          if (characterId && client) {
            try {
              // Use queryObjectStates instead of getObject
              const characterResponse = await client.queryObjectStates({
                filter: {
                  object_id: characterId,
                },
              });
              
              if (characterResponse?.data?.[0]?.decoded_value?.value) {
                const characterObj = characterResponse.data[0];
                const characterData = characterObj.decoded_value.value;
                
                const characterDetails: Character = {
                  id: characterId,
                  name: characterData.name || 'Unnamed Character',
                  username: characterData.username || '',
                  description: characterData.description || ''
                };
                
                setCharacter(characterDetails);
                
                // Initialize edit form with current values
                setEditName(characterDetails.name);
                setEditDescription(characterDetails.description);
                
                // Update agent with character name and description
                setAgent(prev => prev ? {
                  ...prev,
                  name: characterDetails.name,
                  description: characterDetails.description
                } : null);
              }
            } catch (err) {
              console.error('Failed to fetch character details:', err);
              // We don't set an error here as the agent was still loaded
            }
          }
        } else {
          setError('Agent not found');
        }
      } catch (err) {
        console.error('Error processing agent data:', err);
        setError('Failed to process agent data. Please try again.');
      } finally {
        setIsLoading(false);
      }
    };

    processAgentData();
  }, [agentResponse, isAgentLoading, agentError, client, agentId]);

  // Add a separate useEffect to handle the home channel response
  useEffect(() => {
    // Check if home channel query has completed (either with data or null)
    if (!isHomeChannelQueryLoading) {
      if (homeChannelResponse?.return_values?.[0]?.decoded_value) {
        setHomeChannelId(homeChannelResponse.return_values[0].decoded_value);
      } else {
        console.log('No home channel found for this agent');
      }
      
      // Always set loading to false when query completes
      setIsHomeChannelLoading(false);
    }
  }, [homeChannelResponse, isHomeChannelQueryLoading]);

  // Save updated agent information
  const handleSaveAgentInfo = async (field: 'name' | 'description') => {
    if (!client || !packageId || !session || !agentId) {
      setUpdateError('Missing required data for update');
      return;
    }
    
    // Find the matching agent cap for this agent
    const matchingCap = agentCaps.find(cap => cap.agentId === agentId);
    
    if (!matchingCap) {
      setUpdateError('You do not have the required authorization to update this agent');
      return;
    }
    
    // Get current values for fields we're not updating
    const currentName = field === 'description' ? character?.name || '' : editName;
    const currentDescription = field === 'name' ? character?.description || '' : editDescription;
    
    try {
      setIsSaving(true);
      setUpdateError(null);
      setUpdateSuccess(false);

      const tx = new Transaction();
      tx.callFunction({
        target: `${packageId}::agent::update_agent_character_entry`,
        args: [
          Args.objectId(matchingCap.id), 
          Args.string(currentName), 
          Args.string(currentDescription)
        ],
      });
            
      const result = await client.signAndExecuteTransaction({
        transaction: tx,
        signer: session,
      });
      
      if (result.execution_info.status.type !== 'executed') {
        throw new Error('Failed to update agent'+ JSON.stringify(result.execution_info));
      }
      
      setUpdateSuccess(true);
        
      // Close edit mode
      if (field === 'name') setIsEditingName(false);
      if (field === 'description') setIsEditingDescription(false);
      
      refetchAgent();
    } catch (error: any) {
      console.error('Error updating agent:', error);
      setUpdateError(error.message || 'Failed to update agent');
    } finally {
      setIsSaving(false);
    }
  };
  
  // Cancel editing
  const handleCancelEdit = (field: 'name' | 'description') => {
    if (field === 'name') {
      setEditName(character?.name || '');
      setIsEditingName(false);
    } else {
      setEditDescription(character?.description || '');
      setIsEditingDescription(false);
    }
    setUpdateError(null);
  };

  // Helper to map memory response to our type
  const deserializeMemories = (response: any): Memory[] => {
    if (!response?.return_values?.[0]?.value?.value) {
      console.log('No memory data available in response');
      return [];
    }
  
    try {
      // Get the hex value from the response
      const hexValue = response.return_values[0].value.value;
      
      // Convert hex to bytes
      const cleanHexValue = hexValue.startsWith('0x') ? hexValue.slice(2) : hexValue;
      const bytes = new Uint8Array(
        cleanHexValue.match(/.{1,2}/g)?.map(byte => parseInt(byte, 16)) || []
      );
      
      // Parse using BCS
      if (!MemorySchema) {
        console.error('MemorySchema is not defined!');
        return [];
      }
      
      const parsedMemories = bcs.vector(MemorySchema).parse(bytes);
      console.log(`Successfully parsed ${parsedMemories.length} memories`);
      
      // Map to our Memory interface format
      return parsedMemories.map((memory: any) => ({
        index: memory.index || 0,
        content: memory.content || '',
        context: memory.context || '',
        timestamp: parseInt(memory.timestamp) || Date.now(),
      }));
    } catch (error) {
      console.error('Memory BCS deserialization error:', error);
      return [];
    }
  };

  // Fetch agent's self memories
  useEffect(() => {
    const fetchSelfMemories = async () => {
      if (!client || !packageId || !agent?.id) return;
      
      // Add this check to prevent refetching if we already have memories
      if (selfMemories.length > 0) {
        console.log('Self memories already loaded, skipping fetch');
        return;
      }
      
      try {
        setIsLoadingSelfMemories(true);
        
        const response = await client.executeViewFunction({
          target: `${packageId}::agent::get_agent_self_memories`,
          args: [Args.objectId(agent.id)],
        });
        
        // Use BCS to deserialize memories
        let memories: Memory[] = deserializeMemories(response);
        
        setSelfMemories(memories);
        console.log(`Loaded ${memories.length} self memories`);
      } catch (error) {
        console.error('Failed to fetch agent self memories:', error);
      } finally {
        setIsLoadingSelfMemories(false);
      }
    };

    if (agent && client && packageId) {
      fetchSelfMemories();
    }
  }, [agent?.id, client, packageId]); // Remove selfMemories from dependencies

  // Fetch memories about current user
  useEffect(() => {
    const fetchCurrentUserMemories = async () => {
      if (!client || !packageId || !agent?.id || !wallet?.wallet) return;
      
      // Add this check to prevent refetching if we already have memories
      if (userMemories.length > 0) {
        console.log('User memories already loaded, skipping fetch');
        return;
      }
      
      try {
        setIsLoadingUserMemories(true);
        
        const userAddress = wallet.wallet?.getBitcoinAddress().toStr();
        
        const response = await client.executeViewFunction({
          target: `${packageId}::agent::get_agent_memories_about_user`,
          args: [
            Args.objectId(agent.id),
            Args.address(userAddress)
          ],
        });
        
        // Use BCS to deserialize memories
        let memories: Memory[] = deserializeMemories(response);
        
        setUserMemories(memories);
        console.log(`Loaded ${memories.length} user memories`);
      } catch (error) {
        console.error('Failed to fetch agent memories about current user:', error);
      } finally {
        setIsLoadingUserMemories(false);
      }
    };

    if (agent && wallet?.wallet && client && packageId) {
      fetchCurrentUserMemories();
    }
  }, [agent?.id, wallet?.wallet, client, packageId]); // Remove userMemories from dependencies

  // Handle address search
  const handleAddressSearch = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!searchAddress || !client || !packageId || !agent?.id) return;
    
    try {
      setIsSearching(true);
    
      if (!isValidAddress(searchAddress)) {
        throw new Error('Invalid address format');
      }
      
      const response = await client.executeViewFunction({
        target: `${packageId}::agent::get_agent_memories_about_user`,
        args: [
          Args.objectId(agent.id),
          Args.address(searchAddress)
        ],
      });
      
      // Use BCS to deserialize memories
      let memories: Memory[] = deserializeMemories(response);
      
      setSearchResults(memories);
    } catch (error) {
      console.error('Failed to search memories:', error);
      alert('Failed to search memories. Please check the address format.');
    } finally {
      setIsSearching(false);
    }
  }

  // Add a clean-up action to the address search function to clear results when input is cleared
  const handleSearchAddressChange = (value: string) => {
    setSearchAddress(value);
    if (!value) {
      // Clear search results when the input is cleared
      setSearchResults([]);
    }
  };

  if (isLoading) {
    return (
      <Layout>
        <div className="flex justify-center py-12">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
        </div>
      </Layout>
    );
  }

  if (error || !agent) {
    return (
      <Layout>
        <div className="max-w-4xl mx-auto px-4 py-8">
          <div className="bg-red-50 border border-red-200 rounded-md p-4 mb-6">
            <p className="text-red-600">{error || 'Agent not found'}</p>
          </div>
          <button 
            onClick={() => navigate('/')}
            className="text-blue-600 hover:text-blue-800"
          >
            ← Back to Agents
          </button>
        </div>
      </Layout>
    );
  }

  return (
    <Layout>
      <div className="max-w-4xl mx-auto px-4 py-8">
        <button 
          onClick={() => navigate('/')}
          className="text-blue-600 hover:text-blue-800 mb-6 inline-flex items-center"
        >
          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-1" viewBox="0 0 20 20" fill="currentColor">
            <path fillRule="evenodd" d="M9.707 16.707a1 1 0 01-1.414 0l-6-6a1 1 0 010-1.414l6-6a1 1 0 011.414 1.414L5.414 9H17a1 1 0 110 2H5.414l4.293 4.293a1 1 0 010 1.414z" clipRule="evenodd" />
          </svg>
          Back to Agents
        </button>
        
        {/* Status message for updates */}
        {updateSuccess && (
          <div className="mb-4 p-3 bg-green-50 border border-green-200 rounded-md">
            <p className="text-green-700 text-sm">Agent updated successfully!</p>
          </div>
        )}
        {updateError && (
          <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-md">
            <p className="text-red-700 text-sm">{updateError}</p>
          </div>
        )}
        
        <div className="mb-6">
          <div className="bg-white shadow overflow-hidden sm:rounded-lg">
            <div className="px-4 py-5 sm:px-6 flex justify-between items-center">
              {isEditingName && isUserAuthorized ? (
                <div className="flex-1 flex items-center">
                  <input
                    type="text"
                    value={editName}
                    onChange={(e) => setEditName(e.target.value)}
                    className="text-lg font-medium text-gray-900 border border-gray-300 rounded px-2 py-1 mr-2"
                    autoFocus
                  />
                  <div className="flex items-center">
                    <SessionKeyGuard onClick={() => handleSaveAgentInfo('name')}>
                    <button
                      disabled={isSaving}
                      className={`mr-2 text-sm px-3 py-1 rounded ${isSaving ? 'bg-blue-300' : 'bg-blue-600'} text-white`}
                    >
                      {isSaving ? 'Saving...' : 'Save'}
                    </button>
                    </SessionKeyGuard>
                    <button
                      onClick={() => handleCancelEdit('name')}
                      className="text-sm px-3 py-1 rounded bg-gray-200 text-gray-700"
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              ) : (
                <h3 className="text-lg leading-6 font-medium text-gray-900">
                  {agent.name}
                  {isUserAuthorized && (
                    <SessionKeyGuard onClick={() => setIsEditingName(true)} >
                    <button 
                      className="ml-2 text-sm text-blue-600 hover:text-blue-800"
                      title="Edit agent name"
                    >
                      ✎
                    </button>
                    </SessionKeyGuard>
                  )}
                </h3>
              )}
              
              {isUserAuthorized && !isEditingName && (
                <div className="flex items-center">
                  <span className="text-xs text-green-600 flex items-center">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-3 w-3 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                    </svg>
                    Agent Owner
                  </span>
                </div>
              )}
            </div>
          </div>
        </div>
        
        {/* Tabs */}
        <div className="mb-6 border-b border-gray-200">
          <nav className="-mb-px flex space-x-8" aria-label="Tabs">
            <button
              onClick={() => setActiveTab('details')}
              className={`${
                activeTab === 'details'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              } whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm`}
            >
              Agent Details
            </button>
            <button
              onClick={() => setActiveTab('memories')}
              className={`${
                activeTab === 'memories'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              } whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center`}
            >
              Memories
              {isLoadingSelfMemories && (
                <div className="ml-2 animate-spin h-4 w-4 border-t-2 border-blue-500 border-r-2 rounded-full"></div>
              )}
            </button>
          </nav>
        </div>
        
        {/* Tab Content */}
        {activeTab === 'details' ? (
          <>
            {/* Agent Details Tab */}
            <div className="bg-white shadow overflow-hidden sm:rounded-lg">
              <div className="border-t border-gray-200">
                <dl>
                  <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium text-gray-500">Agent ID</dt>
                    <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2 break-all">{agent.id}</dd>
                  </div>
                  
                  <div className="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium text-gray-500">Agent Address</dt>
                    <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2 break-all">
                       <a 
                          href={`${roochscanBaseUrl}/account/${agent.agent_address}`} 
                          target="_blank" 
                          rel="noopener noreferrer"
                          className="cursor-pointer hover:ring-2 hover:ring-blue-300 transition-all rounded-full"
                          title={`View ${shortenAddress(agent.agent_address)} on Roochscan`}
                        >
                      {agent.agent_address}
                      </a>
                    </dd>
                  </div>

                  <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium text-gray-500">Model Provider</dt>
                    <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                      <span className="px-2 py-1 bg-blue-50 rounded text-blue-600 text-xs">
                        {agent.modelProvider}
                      </span>
                    </dd>
                  </div>
                  
                  {character && (
                    <>
                      <div className="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                        <dt className="text-sm font-medium text-gray-500">Character Username</dt>
                        <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                          @{character.username}
                        </dd>
                      </div>
                      
                      <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                        <dt className="text-sm font-medium text-gray-500 flex items-center">
                          Character Description
                          {isUserAuthorized && !isEditingDescription && (
                            <SessionKeyGuard onClick={() => setIsEditingDescription(true)} >
                            <button 
                              className="ml-2 text-xs text-blue-600 hover:text-blue-800"
                              title="Edit description"
                            >
                              ✎ Edit
                            </button>
                            </SessionKeyGuard>
                          )}
                        </dt>
                        <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                          {isEditingDescription && isUserAuthorized ? (
                            <div>
                              <textarea
                                value={editDescription}
                                onChange={(e) => setEditDescription(e.target.value)}
                                className="w-full border border-gray-300 rounded p-2 mb-2"
                                rows={6}
                                placeholder="Enter agent description..."
                              ></textarea>
                              <div className="flex justify-end mt-2">
                                <SessionKeyGuard onClick={() => handleSaveAgentInfo('description')}>
                                <button
                                  disabled={isSaving}
                                  className={`mr-2 text-sm px-3 py-1 rounded ${isSaving ? 'bg-blue-300' : 'bg-blue-600'} text-white`}
                                >
                                  {isSaving ? 'Saving...' : 'Save'}
                                </button>
                                </SessionKeyGuard>
                                <button
                                  onClick={() => handleCancelEdit('description')}
                                  className="text-sm px-3 py-1 rounded bg-gray-200 text-gray-700"
                                >
                                  Cancel
                                </button>
                              </div>
                              <div className="mt-4 border-t border-gray-200 pt-4">
                                <h4 className="text-xs font-medium text-gray-500 mb-2">Preview:</h4>
                                <div className="bg-gray-50 p-3 rounded border border-gray-200">
                                  <ReactMarkdown remarkPlugins={[remarkGfm]}>
                                    {editDescription}
                                  </ReactMarkdown>
                                </div>
                              </div>
                            </div>
                          ) : (
                            <div className="whitespace-pre-wrap">
                              <ReactMarkdown 
                                remarkPlugins={[remarkGfm]}
                                className="prose prose-sm max-w-none"
                                components={{
                                  // Simplified markdown components focused on inline formatting
                                  pre: ({children}) => <>{children}</>,
                                  code: ({node, inline, className, children, ...props}) => {
                                    const match = /language-(\w+)/.exec(className || '');
                                    const language = match ? match[1] : '';
                                    
                                    return inline ? (
                                      <code
                                        className="px-1 py-0.5 rounded bg-gray-100 text-gray-800 text-xs"
                                        {...props}
                                      >
                                        {children}
                                      </code>
                                    ) : (
                                      <div className="my-2">
                                        <SyntaxHighlighter
                                          language={language}
                                          style={oneLight}
                                          customStyle={{
                                            backgroundColor: '#f8fafc',
                                            padding: '0.5rem',
                                            borderRadius: '0.25rem',
                                            border: '1px solid #e2e8f0',
                                            fontSize: '0.75rem',
                                          }}
                                        >
                                          {String(children).replace(/\n$/, '')}
                                        </SyntaxHighlighter>
                                      </div>
                                    );
                                  },
                                  // Override default paragraph to prevent extra margins
                                  p: ({children}) => <p className="m-0">{children}</p>,
                                  // Keep links working
                                  a: ({node, href, children, ...props}) => (
                                    <a 
                                      href={href}
                                      className="text-blue-600 hover:underline"
                                      onClick={(e) => e.stopPropagation()}
                                      {...props}
                                    >
                                      {children}
                                    </a>
                                  ),
                                  // Ensure lists don't break layout
                                  ul: ({children}) => <ul className="list-disc pl-4 my-1">{children}</ul>,
                                  ol: ({children}) => <ol className="list-decimal pl-4 my-1">{children}</ol>,
                                  li: ({children}) => <li className="my-0.5">{children}</li>,
                                }}
                              >
                                {character.description || "No description available."}
                              </ReactMarkdown>
                            </div>
                          )}
                        </dd>
                      </div>
                    </>
                  )}
                  
                  {agent.createdAt && (
                    <div className={`${character?.description ? 'bg-white' : 'bg-gray-50'} px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6`}>
                      <dt className="text-sm font-medium text-gray-500">Last Active</dt>
                      <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                        {new Date(agent.createdAt).toLocaleString()}
                      </dd>
                    </div>
                  )}
                  
                  {agent.characterId && (
                    <div className={`${character?.description || agent.createdAt ? 'bg-white' : 'bg-gray-50'} px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6`}>
                      <dt className="text-sm font-medium text-gray-500">Character ID</dt>
                      <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2 break-all">{agent.characterId}</dd>
                    </div>
                  )}
                  
                  {/* Home Channel section with loading state */}
                  <div className={`${(agent.characterId || agent.createdAt) && (!character?.description) ? 'bg-white' : 'bg-gray-50'} px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6`}>
                    <dt className="text-sm font-medium text-gray-500">Home Channel</dt>
                    <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2 break-all">
                      {isHomeChannelLoading ? (
                        <div className="flex items-center">
                          <div className="animate-spin mr-2 h-4 w-4 border-t-2 border-blue-500 border-r-2 rounded-full"></div>
                          <span className="text-gray-500">Loading home channel...</span>
                        </div>
                      ) : homeChannelId ? (
                        <>
                          <span className="break-all">{homeChannelId}</span>
                          <button 
                            onClick={() => navigate(`/channel/${homeChannelId}`)}
                            className="ml-2 text-blue-600 hover:text-blue-800 text-sm underline"
                          >
                            View
                          </button>
                        </>
                      ) : (
                        <span className="text-gray-500">No home channel found</span>
                      )}
                    </dd>
                  </div>
                </dl>
              </div>
            </div>
          </>
        ) : (
          <>
          </>
        )}
        
        {activeTab === 'memories' && (
          <div className="bg-white shadow overflow-hidden sm:rounded-lg">
            <div className="px-4 py-5 sm:px-6 border-b border-gray-200">
              <h3 className="text-lg leading-6 font-medium text-gray-900">Agent Memories</h3>
              <p className="mt-1 max-w-2xl text-sm text-gray-500">
                Explore memories formed by this agent through interactions
              </p>
            </div>
            
            {/* Memory search component */}
            <div className="px-4 py-4 border-b border-gray-200">
              <form onSubmit={handleAddressSearch} className="flex">
                <input
                  type="text"
                  value={searchAddress}
                  onChange={(e) => handleSearchAddressChange(e.target.value)}
                  placeholder="Enter an address to view memories about them"
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-l-md focus:ring-blue-500 focus:border-blue-500"
                />
                <button
                  type="submit"
                  disabled={isSearching || !searchAddress}
                  className={`px-4 py-2 rounded-r-md font-medium text-white ${
                    isSearching || !searchAddress
                      ? 'bg-gray-400 cursor-not-allowed'
                      : 'bg-blue-600 hover:bg-blue-700'
                  }`}
                >
                  {isSearching ? 
                    <span className="flex items-center">
                      <div className="animate-spin h-4 w-4 mr-2 border-2 border-white border-t-transparent rounded-full"></div>
                      Searching...
                    </span> : 
                    'Search'
                  }
                </button>
              </form>
            </div>
        
            {/* Memory sections */}
            <div className="divide-y divide-gray-200">
              {/* Self memories section */}
              <div className="px-4 py-5">
                <h4 className="text-md font-medium text-gray-900 mb-3">Agent's Self-Memories</h4>
                
                {isLoadingSelfMemories ? (
                  <div className="flex justify-center py-8">
                    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
                  </div>
                ) : selfMemories.length === 0 ? (
                  <p className="text-gray-500 text-center py-4">This agent hasn't formed any self memories yet.</p>
                ) : (
                  <MemoryBrowser memories={selfMemories} />
                )}
              </div>
        
              {/* Current user memories section */}
              <div className="px-4 py-5">
                <h4 className="text-md font-medium text-gray-900 mb-3">Memories About You</h4>
                
                {isLoadingUserMemories ? (
                  <div className="flex justify-center py-8">
                    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
                  </div>
                ) : userMemories.length === 0 ? (
                  <p className="text-gray-500 text-center py-4">
                    This agent hasn't formed any memories about you yet.
                    Interact with the agent to create memories.
                  </p>
                ) : (
                  <MemoryBrowser memories={userMemories} />
                )}
              </div>
        
              {/* Search results section - only show if we've performed a search */}
              {searchAddress && (
                <div className="px-4 py-5">
                  <h4 className="text-md font-medium text-gray-900 mb-3">
                    Memories About Address: <span className="font-mono text-sm">{searchAddress}</span>
                  </h4>
                  
                  {searchResults.length === 0 ? (
                    <p className="text-gray-500 text-center py-4">
                      No memories found for this address.
                    </p>
                  ) : (
                    <MemoryBrowser memories={searchResults} />
                  )}
                </div>
              )}
            </div>
          </div>
        )}
        
        {/* Agent interactions would go here - keep this section the same */}
        <div className="mt-8 p-6 bg-white shadow sm:rounded-lg">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Chat with Agent</h3>
          <p className="text-gray-600 mb-4">Interact with AI agent by sending messages.</p>
          
          <div className="mt-4 flex flex-wrap gap-3">
            {isHomeChannelLoading ? (
              <button
                className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-400 cursor-not-allowed"
                disabled
              >
                <div className="animate-spin mr-2 h-4 w-4 border-t-2 border-white border-r-2 rounded-full"></div>
                Loading Home Channel...
              </button>
            ) : homeChannelId ? (
              <SessionKeyGuard onClick={() => {
                navigate(`/channel/${homeChannelId}`);
              }}>
              <button 
                className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                Go to Home Channel
              </button>
            </SessionKeyGuard>
            ) : (
              <button 
                className="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md shadow-sm text-gray-500 bg-gray-100 cursor-not-allowed"
                disabled
              >
                No Home Channel Available
              </button>
            )}
            <SessionKeyGuard onClick={() => {
              navigate(`/create-channel?agent=${agent.id}`);
            }}>
              <button 
                className="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                New Peer Chat
              </button>
            </SessionKeyGuard>
          </div>
        </div>
      </div>
    </Layout>
  );
}