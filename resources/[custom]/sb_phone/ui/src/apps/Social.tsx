import { useState, useEffect, useRef, useCallback } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { usePhoneStore } from '../store/phoneStore'
import { nuiFetch, notifyTextFieldFocus, onNuiMessage } from '../utils/nui'
import { soundManager } from '../utils/sound'
import { timeAgo } from '../utils/time'
import type { InstapicPost, InstapicProfile, InstapicComment, InstapicStoryGroup, InstapicStory, InstapicDM, InstapicDMConversation, GalleryPhoto } from '../types'
import {
  Heart, MapPin, Plus, X, Send, Search, MessageCircle, User, Home,
  Compass, Camera, ChevronLeft, MoreHorizontal, Trash2, UserPlus, UserMinus, Grid3X3, Edit3,
  Image, Link, Aperture
} from 'lucide-react'

type View =
  | 'feed' | 'explore' | 'create' | 'dms' | 'profile'
  | 'post-detail' | 'comments' | 'story-viewer' | 'dm-chat'
  | 'search' | 'other-profile' | 'followers' | 'following'

interface ViewState {
  view: View
  data?: any
}

export default function Social() {
  const { instapicProfile, setInstapicProfile, instapicFeed, setInstapicFeed, instapicStories, setInstapicStories, metadata } = usePhoneStore()

  const [viewStack, setViewStack] = useState<ViewState[]>([{ view: 'feed' }])
  const current = viewStack[viewStack.length - 1]
  const [activeTab, setActiveTab] = useState<'feed' | 'explore' | 'create' | 'dms' | 'profile'>('feed')

  const pushView = (view: View, data?: any) => {
    setViewStack(prev => [...prev, { view, data }])
  }
  const popView = () => {
    setViewStack(prev => prev.length > 1 ? prev.slice(0, -1) : prev)
  }
  const switchTab = (tab: typeof activeTab) => {
    setActiveTab(tab)
    setViewStack([{ view: tab }])
  }

  // Load feed + stories on mount
  useEffect(() => {
    loadFeed()
    loadStories()
    if (!instapicProfile) loadMyProfile()

    const unsub = onNuiMessage('instapicDM', () => {
      // Real-time DM received — handled inside DMListView and DMChatView
    })
    return () => unsub()
  }, [])

  const loadMyProfile = async () => {
    const p = await nuiFetch<InstapicProfile>('getInstapicProfile', {})
    if (p?.citizenid) setInstapicProfile(p)
  }

  const loadFeed = async () => {
    const posts = await nuiFetch<InstapicPost[]>('getInstapicFeed')
    if (Array.isArray(posts)) setInstapicFeed(posts)
  }

  const loadStories = async () => {
    const groups = await nuiFetch<InstapicStoryGroup[]>('getInstapicStories')
    if (Array.isArray(groups)) setInstapicStories(groups)
  }

  const myCid = metadata?.ownerCitizenid || ''

  // =========================================================================
  // SUB-VIEWS
  // =========================================================================

  return (
    <div className="flex flex-col h-full bg-[#0e0e0f]">
      <div className="flex-1 overflow-hidden relative">
        <AnimatePresence mode="wait">
          <motion.div
            key={current.view + (current.data?.id || current.data?.citizenid || '')}
            initial={{ opacity: 0, x: 30 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -30 }}
            transition={{ duration: 0.15 }}
            className="absolute inset-0 flex flex-col overflow-hidden"
          >
            {current.view === 'feed' && (
              <FeedView
                posts={instapicFeed}
                stories={instapicStories}
                myCid={myCid}
                onPostTap={(post) => pushView('post-detail', post)}
                onProfileTap={(cid) => pushView('other-profile', { citizenid: cid })}
                onStoryTap={(group, idx) => pushView('story-viewer', { group, startIdx: idx })}
                onAddStory={() => pushView('create', { storyMode: true })}
                onToggleLike={async (postId) => {
                  const res = await nuiFetch<{ liked: boolean; likeCount: number }>('toggleInstapicLike', { postId })
                  if (res) {
                    setInstapicFeed(instapicFeed.map(p =>
                      p.id === postId ? { ...p, user_liked: res.liked ? 1 : 0, like_count: res.likeCount } : p
                    ))
                  }
                }}
                onRefresh={loadFeed}
              />
            )}
            {current.view === 'explore' && (
              <ExploreView
                myCid={myCid}
                onPostTap={(post) => pushView('post-detail', post)}
                onSearchTap={() => pushView('search')}
              />
            )}
            {current.view === 'create' && (
              <CreateView
                storyMode={current.data?.storyMode}
                onClose={popView}
                onCreated={(post) => {
                  if (post) setInstapicFeed([post, ...instapicFeed])
                  popView()
                }}
                onStoryCreated={() => { loadStories(); popView() }}
              />
            )}
            {current.view === 'dms' && (
              <DMListView
                myCid={myCid}
                onChatTap={(convo) => pushView('dm-chat', convo)}
              />
            )}
            {current.view === 'profile' && (
              <ProfileView
                citizenid={myCid}
                isMe={true}
                onBack={popView}
                onPostTap={(post) => pushView('post-detail', post)}
                onFollowers={(cid) => pushView('followers', { citizenid: cid })}
                onFollowing={(cid) => pushView('following', { citizenid: cid })}
                onProfileUpdated={loadMyProfile}
              />
            )}
            {current.view === 'other-profile' && (
              <ProfileView
                citizenid={current.data?.citizenid}
                isMe={current.data?.citizenid === myCid}
                onBack={popView}
                onPostTap={(post) => pushView('post-detail', post)}
                onFollowers={(cid) => pushView('followers', { citizenid: cid })}
                onFollowing={(cid) => pushView('following', { citizenid: cid })}
                onMessage={(cid) => pushView('dm-chat', { citizenid: cid, username: current.data?.username || '' })}
                onProfileUpdated={loadMyProfile}
              />
            )}
            {current.view === 'post-detail' && (
              <PostDetailView
                post={current.data}
                myCid={myCid}
                onBack={popView}
                onProfileTap={(cid) => pushView('other-profile', { citizenid: cid })}
                onCommentsTap={(post) => pushView('comments', { postId: post.id })}
                onToggleLike={async (postId) => {
                  const res = await nuiFetch<{ liked: boolean; likeCount: number }>('toggleInstapicLike', { postId })
                  if (res) {
                    setInstapicFeed(instapicFeed.map(p =>
                      p.id === postId ? { ...p, user_liked: res.liked ? 1 : 0, like_count: res.likeCount } : p
                    ))
                  }
                  return res
                }}
                onDelete={async (postId) => {
                  await nuiFetch('deleteInstapicPost', { postId })
                  setInstapicFeed(instapicFeed.filter(p => p.id !== postId))
                  popView()
                }}
              />
            )}
            {current.view === 'comments' && (
              <CommentsView
                postId={current.data?.postId}
                myCid={myCid}
                onBack={popView}
              />
            )}
            {current.view === 'story-viewer' && (
              <StoryViewer
                group={current.data?.group}
                startIdx={current.data?.startIdx || 0}
                onClose={popView}
              />
            )}
            {current.view === 'dm-chat' && (
              <DMChatView
                otherCitizenid={current.data?.citizenid}
                otherUsername={current.data?.username}
                myCid={myCid}
                onBack={popView}
              />
            )}
            {current.view === 'search' && (
              <SearchView
                onBack={popView}
                onProfileTap={(cid) => pushView('other-profile', { citizenid: cid })}
              />
            )}
            {current.view === 'followers' && (
              <UserListView
                title="Followers"
                citizenid={current.data?.citizenid}
                mode="followers"
                myCid={myCid}
                onBack={popView}
                onProfileTap={(cid) => pushView('other-profile', { citizenid: cid })}
              />
            )}
            {current.view === 'following' && (
              <UserListView
                title="Following"
                citizenid={current.data?.citizenid}
                mode="following"
                myCid={myCid}
                onBack={popView}
                onProfileTap={(cid) => pushView('other-profile', { citizenid: cid })}
              />
            )}
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Bottom tab bar */}
      {!['story-viewer', 'create'].includes(current.view) && (
        <div className="flex items-center justify-around h-12 bg-[#111] border-t border-white/5 shrink-0">
          <TabBtn icon={<Home size={22} />} active={activeTab === 'feed'} onTap={() => switchTab('feed')} />
          <TabBtn icon={<Compass size={22} />} active={activeTab === 'explore'} onTap={() => switchTab('explore')} />
          <TabBtn icon={<Plus size={24} />} active={false} onTap={() => pushView('create')} isCreate />
          <TabBtn icon={<MessageCircle size={22} />} active={activeTab === 'dms'} onTap={() => switchTab('dms')} />
          <TabBtn icon={<User size={22} />} active={activeTab === 'profile'} onTap={() => switchTab('profile')} />
        </div>
      )}
    </div>
  )
}

// ============================================================================
// TAB BUTTON
// ============================================================================
function TabBtn({ icon, active, onTap, isCreate }: { icon: React.ReactNode; active: boolean; onTap: () => void; isCreate?: boolean }) {
  return (
    <button
      onClick={() => { soundManager.tap(); onTap() }}
      className={`p-2 rounded-lg transition-colors ${isCreate ? 'bg-gradient-to-br from-pink-500 to-orange-400 text-white rounded-xl' : active ? 'text-white' : 'text-white/40'}`}
    >
      {icon}
    </button>
  )
}

// ============================================================================
// FEED VIEW
// ============================================================================
function FeedView({ posts, stories, myCid, onPostTap, onProfileTap, onStoryTap, onAddStory, onToggleLike, onRefresh }: {
  posts: InstapicPost[]
  stories: InstapicStoryGroup[]
  myCid: string
  onPostTap: (p: InstapicPost) => void
  onProfileTap: (cid: string) => void
  onStoryTap: (group: InstapicStoryGroup, idx: number) => void
  onAddStory: () => void
  onToggleLike: (id: number) => void
  onRefresh: () => void
}) {
  useEffect(() => { onRefresh() }, [])

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center justify-between px-4 pt-2 pb-2 border-b border-white/5">
        <h1 className="text-white text-lg font-bold" style={{ fontFamily: 'serif', fontStyle: 'italic' }}>Instapic</h1>
      </div>
      <div className="flex-1 overflow-y-auto">
        {/* Stories row */}
        <div className="flex gap-3 px-4 py-3 overflow-x-auto">
          <button onClick={onAddStory} className="flex flex-col items-center gap-1 min-w-[60px]">
            <div className="w-14 h-14 rounded-full border-2 border-dashed border-pink-400/50 flex items-center justify-center">
              <Plus size={20} className="text-pink-400" />
            </div>
            <span className="text-white/50 text-[10px]">Your Story</span>
          </button>
          {stories.map((group, gi) => (
            <button key={group.author_citizenid} onClick={() => onStoryTap(group, gi)} className="flex flex-col items-center gap-1 min-w-[60px]">
              <div className={`w-14 h-14 rounded-full p-[2px] ${group.has_unviewed ? 'bg-gradient-to-br from-pink-500 via-red-500 to-yellow-500' : 'bg-white/20'}`}>
                <div className="w-full h-full rounded-full bg-[#0e0e0f] flex items-center justify-center">
                  <span className="text-white text-sm font-bold">{group.author_name[0]?.toUpperCase()}</span>
                </div>
              </div>
              <span className="text-white/50 text-[10px] truncate w-14 text-center">{group.author_name.split(' ')[0]}</span>
            </button>
          ))}
        </div>

        {/* Posts */}
        <div className="pb-4">
          {posts.length === 0 ? (
            <p className="text-white/30 text-center mt-12 text-sm">Follow people to see their posts here</p>
          ) : (
            posts.map(post => (
              <PostCard
                key={post.id}
                post={post}
                myCid={myCid}
                onTap={() => onPostTap(post)}
                onProfileTap={() => onProfileTap(post.author_citizenid)}
                onToggleLike={() => onToggleLike(post.id)}
                onCommentTap={() => onPostTap(post)}
              />
            ))
          )}
        </div>
      </div>
    </div>
  )
}

// ============================================================================
// POST CARD
// ============================================================================
function PostCard({ post, myCid, onTap, onProfileTap, onToggleLike, onCommentTap }: {
  post: InstapicPost
  myCid: string
  onTap: () => void
  onProfileTap: () => void
  onToggleLike: () => void
  onCommentTap: () => void
}) {
  const [animHeart, setAnimHeart] = useState(false)

  const handleLike = () => {
    onToggleLike()
    if (!post.user_liked) {
      setAnimHeart(true)
      setTimeout(() => setAnimHeart(false), 600)
    }
  }

  return (
    <div className="border-b border-white/5">
      {/* Header */}
      <div className="flex items-center gap-2.5 px-4 py-2">
        <button onClick={onProfileTap} className="w-8 h-8 rounded-full bg-gradient-to-br from-pink-500 to-orange-400 flex items-center justify-center">
          <span className="text-white text-xs font-bold">{post.author_name[0]?.toUpperCase()}</span>
        </button>
        <button onClick={onProfileTap} className="flex-1 text-left">
          <p className="text-white text-xs font-semibold">{post.author_name}</p>
          {post.location && <p className="text-white/40 text-[10px]">{post.location}</p>}
        </button>
      </div>

      {/* Image / Gradient */}
      <div
        className="w-full aspect-square relative flex items-center justify-center cursor-pointer"
        style={{ background: post.image_url ? undefined : post.image_gradient }}
        onDoubleClick={handleLike}
        onClick={onTap}
      >
        {post.image_url ? (
          <img src={post.image_url} alt="" className="w-full h-full object-cover" onError={(e) => {
            (e.target as HTMLImageElement).style.display = 'none';
            (e.target as HTMLImageElement).parentElement!.style.background = post.image_gradient
          }} />
        ) : (
          post.caption && <p className="text-white text-center text-lg font-medium leading-snug px-6">{post.caption}</p>
        )}
        <AnimatePresence>
          {animHeart && (
            <motion.div
              initial={{ scale: 0, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 1.5, opacity: 0 }}
              className="absolute inset-0 flex items-center justify-center pointer-events-none"
            >
              <Heart size={80} className="text-white fill-white drop-shadow-lg" />
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Actions */}
      <div className="px-4 py-2">
        <div className="flex items-center gap-4">
          <button onClick={handleLike} className="flex items-center gap-1">
            <Heart size={22} className={post.user_liked ? 'text-red-500 fill-red-500' : 'text-white'} />
          </button>
          <button onClick={onCommentTap} className="flex items-center gap-1">
            <MessageCircle size={22} className="text-white" />
          </button>
        </div>
        <p className="text-white text-xs font-semibold mt-1">{post.like_count} likes</p>
        {post.caption && post.image_url && (
          <p className="text-white text-xs mt-0.5">
            <span className="font-semibold">{post.author_name}</span>{' '}{post.caption}
          </p>
        )}
        {post.comment_count > 0 && (
          <button onClick={onCommentTap} className="text-white/40 text-xs mt-0.5">
            View all {post.comment_count} comments
          </button>
        )}
        <p className="text-white/30 text-[10px] mt-1">{timeAgo(post.created_at)}</p>
      </div>
    </div>
  )
}

// ============================================================================
// EXPLORE VIEW
// ============================================================================
function ExploreView({ myCid, onPostTap, onSearchTap }: {
  myCid: string
  onPostTap: (p: InstapicPost) => void
  onSearchTap: () => void
}) {
  const [posts, setPosts] = useState<InstapicPost[]>([])

  useEffect(() => {
    (async () => {
      const data = await nuiFetch<InstapicPost[]>('getInstapicExplore')
      if (Array.isArray(data)) setPosts(data)
    })()
  }, [])

  return (
    <div className="flex flex-col h-full">
      <div className="px-4 pt-2 pb-2">
        <button onClick={onSearchTap} className="w-full bg-white/10 rounded-lg px-3 py-2 flex items-center gap-2">
          <Search size={16} className="text-white/40" />
          <span className="text-white/40 text-sm">Search</span>
        </button>
      </div>
      <div className="flex-1 overflow-y-auto px-0.5">
        <div className="grid grid-cols-3 gap-0.5">
          {posts.map(post => (
            <button
              key={post.id}
              onClick={() => onPostTap(post)}
              className="aspect-square relative"
              style={{ background: post.image_url ? '#1a1a1a' : post.image_gradient }}
            >
              {post.image_url ? (
                <img src={post.image_url} alt="" className="w-full h-full object-cover" onError={(e) => {
                  (e.target as HTMLImageElement).style.display = 'none';
                  (e.target as HTMLImageElement).parentElement!.style.background = post.image_gradient
                }} />
              ) : (
                <div className="w-full h-full flex items-center justify-center p-1">
                  <p className="text-white text-[8px] text-center line-clamp-3">{post.caption}</p>
                </div>
              )}
            </button>
          ))}
        </div>
        {posts.length === 0 && (
          <p className="text-white/30 text-center mt-12 text-sm">No trending posts yet</p>
        )}
      </div>
    </div>
  )
}

// ============================================================================
// CREATE VIEW (Post or Story)
// ============================================================================
function CreateView({ storyMode, onClose, onCreated, onStoryCreated }: {
  storyMode?: boolean
  onClose: () => void
  onCreated: (post: InstapicPost | null) => void
  onStoryCreated: () => void
}) {
  const { gallery } = usePhoneStore()
  const [isStory, setIsStory] = useState(!!storyMode)
  const [caption, setCaption] = useState('')
  const [imageUrl, setImageUrl] = useState('')
  const [location, setLocation] = useState('')
  const [posting, setPosting] = useState(false)
  const [showGalleryPicker, setShowGalleryPicker] = useState(false)
  const [showUrlInput, setShowUrlInput] = useState(false)
  const [galleryPhotos, setGalleryPhotos] = useState<GalleryPhoto[]>(gallery)
  const [capturing, setCapturing] = useState(false)

  // Load gallery
  useEffect(() => {
    (async () => {
      const photos = await nuiFetch<GalleryPhoto[]>('getGalleryPhotos')
      if (Array.isArray(photos)) setGalleryPhotos(photos)
    })()
  }, [])

  const takePhoto = async () => {
    setCapturing(true)
    soundManager.shutter()
    const res = await nuiFetch<{ success: boolean; url?: string }>('capturePhoto', { saveToGallery: true })
    setCapturing(false)
    if (res?.success && res.url) {
      setImageUrl(res.url)
    }
  }

  const createPost = async () => {
    if (!caption.trim() && !imageUrl.trim()) return
    setPosting(true)
    const post = await nuiFetch<InstapicPost>('createInstapicPost', {
      caption: caption.trim(),
      imageUrl: imageUrl.trim() || null,
      location: location.trim() || null,
    })
    soundManager.send()
    onCreated(post || null)
  }

  const createStory = async () => {
    setPosting(true)
    const colors = ['#ff6b35', '#30d158', '#0a84ff', '#bf5af2', '#ff453a', '#ffd60a', '#e91e63', '#ff5722']
    const color = colors[Math.floor(Math.random() * colors.length)]
    await nuiFetch('addInstapicStory', { color, imageUrl: imageUrl.trim() || null })
    soundManager.send()
    onStoryCreated()
  }

  return (
    <div className="flex flex-col h-full bg-[#0e0e0f]">
      <div className="flex items-center justify-between px-4 pt-3 pb-2">
        <button onClick={onClose} className="text-white/60 text-sm">Cancel</button>
        <h2 className="text-white font-semibold text-sm">{isStory ? 'New Story' : 'New Post'}</h2>
        <button
          onClick={isStory ? createStory : createPost}
          disabled={posting || (!isStory && !caption.trim() && !imageUrl.trim())}
          className="text-blue-400 text-sm font-semibold disabled:opacity-30"
        >
          Share
        </button>
      </div>

      {/* Toggle */}
      <div className="flex mx-4 mb-3 bg-white/5 rounded-lg p-0.5">
        <button onClick={() => setIsStory(false)} className={`flex-1 py-1.5 rounded-md text-xs font-medium ${!isStory ? 'bg-white/10 text-white' : 'text-white/40'}`}>Post</button>
        <button onClick={() => setIsStory(true)} className={`flex-1 py-1.5 rounded-md text-xs font-medium ${isStory ? 'bg-white/10 text-white' : 'text-white/40'}`}>Story</button>
      </div>

      <div className="px-4 space-y-3 flex-1 overflow-y-auto">
        {!isStory && (
          <textarea
            value={caption}
            onChange={e => setCaption(e.target.value.slice(0, 300))}
            onFocus={() => notifyTextFieldFocus(true)}
            onBlur={() => notifyTextFieldFocus(false)}
            placeholder="Write a caption..."
            rows={3}
            className="w-full bg-white/5 rounded-xl px-4 py-3 text-white text-sm outline-none placeholder:text-white/30 resize-none"
          />
        )}

        {/* Image source buttons */}
        <div className="flex gap-2">
          <button
            onClick={takePhoto}
            disabled={capturing}
            className="flex-1 bg-gradient-to-r from-pink-500 to-orange-400 rounded-xl py-3 flex items-center justify-center gap-2 disabled:opacity-50"
          >
            <Aperture size={16} className="text-white" />
            <span className="text-white text-xs font-medium">{capturing ? 'Capturing...' : 'Take Photo'}</span>
          </button>
          <button
            onClick={() => setShowGalleryPicker(!showGalleryPicker)}
            className="flex-1 bg-white/10 rounded-xl py-3 flex items-center justify-center gap-2"
          >
            <Image size={16} className="text-white" />
            <span className="text-white text-xs font-medium">Gallery</span>
          </button>
          <button
            onClick={() => setShowUrlInput(!showUrlInput)}
            className="bg-white/10 rounded-xl px-3 py-3 flex items-center justify-center"
          >
            <Link size={16} className="text-white" />
          </button>
        </div>

        {/* URL input (hidden by default) */}
        {showUrlInput && (
          <div className="flex items-center gap-2 bg-white/5 rounded-lg px-3 py-2.5">
            <Link size={14} className="text-white/40 shrink-0" />
            <input
              type="text"
              value={imageUrl}
              onChange={e => setImageUrl(e.target.value)}
              onFocus={() => notifyTextFieldFocus(true)}
              onBlur={() => notifyTextFieldFocus(false)}
              placeholder="Paste image URL..."
              className="flex-1 bg-transparent text-white text-sm outline-none placeholder:text-white/30"
            />
            {imageUrl && (
              <button onClick={() => setImageUrl('')} className="text-white/40"><X size={14} /></button>
            )}
          </div>
        )}

        {/* Gallery picker grid */}
        <AnimatePresence>
          {showGalleryPicker && (
            <motion.div
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: 'auto', opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              className="overflow-hidden"
            >
              {galleryPhotos.length === 0 ? (
                <p className="text-white/30 text-xs text-center py-4">No photos in gallery. Take some with the Camera app!</p>
              ) : (
                <div className="grid grid-cols-4 gap-1 max-h-40 overflow-y-auto rounded-lg">
                  {galleryPhotos.map(photo => (
                    <button
                      key={photo.id}
                      onClick={() => { setImageUrl(photo.image_url); setShowGalleryPicker(false) }}
                      className={`aspect-square rounded overflow-hidden border-2 ${imageUrl === photo.image_url ? 'border-pink-500' : 'border-transparent'}`}
                    >
                      <img src={photo.image_url} alt="" className="w-full h-full object-cover" />
                    </button>
                  ))}
                </div>
              )}
            </motion.div>
          )}
        </AnimatePresence>

        {!isStory && (
          <div className="flex items-center gap-2 bg-white/5 rounded-lg px-3 py-2.5">
            <MapPin size={16} className="text-white/40 shrink-0" />
            <input
              type="text"
              value={location}
              onChange={e => setLocation(e.target.value.slice(0, 100))}
              onFocus={() => notifyTextFieldFocus(true)}
              onBlur={() => notifyTextFieldFocus(false)}
              placeholder="Add location"
              className="flex-1 bg-transparent text-white text-sm outline-none placeholder:text-white/30"
            />
          </div>
        )}

        {/* Preview */}
        {imageUrl.trim() && (
          <div className="relative rounded-xl overflow-hidden aspect-square bg-white/5">
            <img src={imageUrl} alt="Preview" className="w-full h-full object-cover" onError={(e) => {
              (e.target as HTMLImageElement).style.display = 'none'
            }} />
            <button
              onClick={() => setImageUrl('')}
              className="absolute top-2 right-2 w-7 h-7 rounded-full bg-black/60 flex items-center justify-center"
            >
              <X size={14} className="text-white" />
            </button>
          </div>
        )}

        {!isStory && <p className="text-white/30 text-xs text-right">{caption.length}/300</p>}
      </div>
    </div>
  )
}

// ============================================================================
// POST DETAIL VIEW
// ============================================================================
function PostDetailView({ post: initialPost, myCid, onBack, onProfileTap, onCommentsTap, onToggleLike, onDelete }: {
  post: InstapicPost
  myCid: string
  onBack: () => void
  onProfileTap: (cid: string) => void
  onCommentsTap: (post: InstapicPost) => void
  onToggleLike: (id: number) => Promise<{ liked: boolean; likeCount: number } | undefined>
  onDelete: (id: number) => void
}) {
  const { instapicFeed } = usePhoneStore()
  const post = instapicFeed.find(p => p.id === initialPost.id) || initialPost
  const isOwn = post.author_citizenid === myCid

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center px-4 pt-2 pb-2 border-b border-white/5">
        <button onClick={onBack} className="text-white mr-3"><ChevronLeft size={22} /></button>
        <h2 className="text-white font-semibold text-sm flex-1">Post</h2>
        {isOwn && (
          <button onClick={() => onDelete(post.id)} className="text-red-400"><Trash2 size={18} /></button>
        )}
      </div>
      <div className="flex-1 overflow-y-auto">
        <PostCard
          post={post}
          myCid={myCid}
          onTap={() => {}}
          onProfileTap={() => onProfileTap(post.author_citizenid)}
          onToggleLike={async () => { await onToggleLike(post.id) }}
          onCommentTap={() => onCommentsTap(post)}
        />
      </div>
    </div>
  )
}

// ============================================================================
// COMMENTS VIEW
// ============================================================================
function CommentsView({ postId, myCid, onBack }: {
  postId: number
  myCid: string
  onBack: () => void
}) {
  const [comments, setComments] = useState<InstapicComment[]>([])
  const [text, setText] = useState('')
  const scrollRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    (async () => {
      const data = await nuiFetch<InstapicComment[]>('getInstapicComments', { postId })
      if (Array.isArray(data)) setComments(data)
    })()
  }, [postId])

  const addComment = async () => {
    if (!text.trim()) return
    const comment = await nuiFetch<InstapicComment>('addInstapicComment', { postId, content: text.trim() })
    if (comment) {
      setComments(prev => [...prev, comment])
      setText('')
      setTimeout(() => scrollRef.current?.scrollTo(0, scrollRef.current.scrollHeight), 100)
    }
  }

  const deleteComment = async (commentId: number) => {
    const res = await nuiFetch<{ success: boolean }>('deleteInstapicComment', { commentId })
    if (res?.success) setComments(prev => prev.filter(c => c.id !== commentId))
  }

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center px-4 pt-2 pb-2 border-b border-white/5">
        <button onClick={onBack} className="text-white mr-3"><ChevronLeft size={22} /></button>
        <h2 className="text-white font-semibold text-sm">Comments</h2>
      </div>
      <div ref={scrollRef} className="flex-1 overflow-y-auto px-4 py-2 space-y-3">
        {comments.length === 0 && <p className="text-white/30 text-center text-sm mt-8">No comments yet</p>}
        {comments.map(c => (
          <div key={c.id} className="flex gap-2">
            <div className="w-7 h-7 rounded-full bg-white/10 flex items-center justify-center shrink-0 mt-0.5">
              <span className="text-white text-[10px] font-bold">{c.author_name[0]?.toUpperCase()}</span>
            </div>
            <div className="flex-1">
              <p className="text-white text-xs">
                <span className="font-semibold">{c.author_name}</span>{' '}{c.content}
              </p>
              <div className="flex items-center gap-2 mt-0.5">
                <span className="text-white/30 text-[10px]">{timeAgo(c.created_at)}</span>
                {c.author_citizenid === myCid && (
                  <button onClick={() => deleteComment(c.id)} className="text-red-400/60 text-[10px]">Delete</button>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>
      <div className="flex items-center gap-2 px-4 py-2 border-t border-white/5">
        <input
          type="text"
          value={text}
          onChange={e => setText(e.target.value.slice(0, 500))}
          onFocus={() => notifyTextFieldFocus(true)}
          onBlur={() => notifyTextFieldFocus(false)}
          placeholder="Add a comment..."
          className="flex-1 bg-white/5 rounded-full px-4 py-2 text-white text-xs outline-none placeholder:text-white/30"
          onKeyDown={e => e.key === 'Enter' && addComment()}
        />
        <button onClick={addComment} disabled={!text.trim()} className="text-blue-400 disabled:opacity-30">
          <Send size={18} />
        </button>
      </div>
    </div>
  )
}

// ============================================================================
// PROFILE VIEW
// ============================================================================
function ProfileView({ citizenid, isMe, onBack, onPostTap, onFollowers, onFollowing, onMessage, onProfileUpdated }: {
  citizenid: string
  isMe: boolean
  onBack: () => void
  onPostTap: (p: InstapicPost) => void
  onFollowers: (cid: string) => void
  onFollowing: (cid: string) => void
  onMessage?: (cid: string) => void
  onProfileUpdated?: () => void
}) {
  const [profile, setProfile] = useState<InstapicProfile | null>(null)
  const [posts, setPosts] = useState<InstapicPost[]>([])
  const [editingBio, setEditingBio] = useState(false)
  const [bioText, setBioText] = useState('')

  useEffect(() => {
    (async () => {
      const p = await nuiFetch<InstapicProfile>('getInstapicProfile', { citizenid })
      if (p?.citizenid) setProfile(p)
      const userPosts = await nuiFetch<InstapicPost[]>('getInstapicUserPosts', { citizenid })
      if (Array.isArray(userPosts)) setPosts(userPosts)
    })()
  }, [citizenid])

  const toggleFollow = async () => {
    if (!profile) return
    const res = await nuiFetch<{ following: boolean }>('toggleInstapicFollow', { citizenid })
    if (res) {
      setProfile({
        ...profile,
        is_following: res.following,
        follower_count: profile.follower_count + (res.following ? 1 : -1),
      })
    }
  }

  const saveBio = async () => {
    await nuiFetch('updateInstapicBio', { bio: bioText })
    setProfile(prev => prev ? { ...prev, bio: bioText } : prev)
    setEditingBio(false)
    onProfileUpdated?.()
  }

  if (!profile) return <div className="flex items-center justify-center h-full"><p className="text-white/30 text-sm">Loading...</p></div>

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center px-4 pt-2 pb-2 border-b border-white/5">
        <button onClick={onBack} className="text-white mr-3"><ChevronLeft size={22} /></button>
        <h2 className="text-white font-semibold text-sm flex-1">{profile.username}</h2>
      </div>
      <div className="flex-1 overflow-y-auto">
        {/* Profile header */}
        <div className="px-4 py-4">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 rounded-full bg-gradient-to-br from-pink-500 to-orange-400 flex items-center justify-center">
              <span className="text-white text-xl font-bold">{profile.username[0]?.toUpperCase()}</span>
            </div>
            <div className="flex-1 flex justify-around">
              <div className="text-center">
                <p className="text-white text-sm font-bold">{profile.post_count}</p>
                <p className="text-white/40 text-[10px]">Posts</p>
              </div>
              <button onClick={() => onFollowers(citizenid)} className="text-center">
                <p className="text-white text-sm font-bold">{profile.follower_count}</p>
                <p className="text-white/40 text-[10px]">Followers</p>
              </button>
              <button onClick={() => onFollowing(citizenid)} className="text-center">
                <p className="text-white text-sm font-bold">{profile.following_count}</p>
                <p className="text-white/40 text-[10px]">Following</p>
              </button>
            </div>
          </div>

          <p className="text-white text-xs font-semibold mt-2">{profile.username}</p>
          {editingBio ? (
            <div className="mt-1 flex gap-2">
              <input
                type="text"
                value={bioText}
                onChange={e => setBioText(e.target.value.slice(0, 300))}
                onFocus={() => notifyTextFieldFocus(true)}
                onBlur={() => notifyTextFieldFocus(false)}
                className="flex-1 bg-white/5 rounded px-2 py-1 text-white text-xs outline-none"
                autoFocus
              />
              <button onClick={saveBio} className="text-blue-400 text-xs">Save</button>
              <button onClick={() => setEditingBio(false)} className="text-white/40 text-xs">Cancel</button>
            </div>
          ) : (
            <p className="text-white/60 text-xs mt-0.5">{profile.bio || (isMe ? 'Tap edit to add a bio' : '')}</p>
          )}

          {/* Action buttons */}
          <div className="flex gap-2 mt-3">
            {isMe ? (
              <button onClick={() => { setBioText(profile.bio || ''); setEditingBio(true) }} className="flex-1 bg-white/10 rounded-lg py-1.5 text-white text-xs font-medium flex items-center justify-center gap-1">
                <Edit3 size={12} /> Edit Profile
              </button>
            ) : (
              <>
                <button onClick={toggleFollow} className={`flex-1 rounded-lg py-1.5 text-xs font-medium ${profile.is_following ? 'bg-white/10 text-white' : 'bg-blue-500 text-white'}`}>
                  {profile.is_following ? 'Following' : 'Follow'}
                </button>
                {onMessage && (
                  <button onClick={() => onMessage(citizenid)} className="flex-1 bg-white/10 rounded-lg py-1.5 text-white text-xs font-medium">
                    Message
                  </button>
                )}
              </>
            )}
          </div>
        </div>

        {/* Post grid */}
        <div className="border-t border-white/5 px-0.5 pt-0.5">
          <div className="grid grid-cols-3 gap-0.5">
            {posts.map(post => (
              <button
                key={post.id}
                onClick={() => onPostTap(post)}
                className="aspect-square relative"
                style={{ background: post.image_url ? '#1a1a1a' : post.image_gradient }}
              >
                {post.image_url ? (
                  <img src={post.image_url} alt="" className="w-full h-full object-cover" onError={(e) => {
                    (e.target as HTMLImageElement).style.display = 'none';
                    (e.target as HTMLImageElement).parentElement!.style.background = post.image_gradient
                  }} />
                ) : (
                  <div className="w-full h-full flex items-center justify-center p-1">
                    <p className="text-white text-[8px] text-center line-clamp-3">{post.caption}</p>
                  </div>
                )}
              </button>
            ))}
          </div>
          {posts.length === 0 && (
            <p className="text-white/30 text-center mt-8 text-sm">No posts yet</p>
          )}
        </div>
      </div>
    </div>
  )
}

// ============================================================================
// STORY VIEWER
// ============================================================================
function StoryViewer({ group, startIdx, onClose }: {
  group: InstapicStoryGroup
  startIdx: number
  onClose: () => void
}) {
  const [currentIdx, setCurrentIdx] = useState(0)
  const stories = group.stories
  const story = stories[currentIdx]
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    // Mark as viewed
    if (story) nuiFetch('viewInstapicStory', { storyId: story.id })
  }, [currentIdx])

  useEffect(() => {
    const advance = () => {
      if (currentIdx < stories.length - 1) {
        setCurrentIdx(prev => prev + 1)
      } else {
        onClose()
      }
    }
    timerRef.current = setTimeout(advance, 5000)
    return () => { if (timerRef.current) clearTimeout(timerRef.current) }
  }, [currentIdx, stories.length])

  if (!story) return null

  const goNext = () => {
    if (timerRef.current) clearTimeout(timerRef.current)
    if (currentIdx < stories.length - 1) setCurrentIdx(prev => prev + 1)
    else onClose()
  }
  const goPrev = () => {
    if (timerRef.current) clearTimeout(timerRef.current)
    if (currentIdx > 0) setCurrentIdx(prev => prev - 1)
  }

  return (
    <div className="absolute inset-0 z-50 bg-black flex flex-col" style={{ background: story.image_url ? '#000' : story.color }}>
      {/* Progress bars */}
      <div className="flex gap-1 px-3 pt-2">
        {stories.map((_, i) => (
          <div key={i} className="flex-1 h-[2px] bg-white/20 rounded-full overflow-hidden">
            <motion.div
              className="h-full bg-white"
              initial={{ width: i < currentIdx ? '100%' : '0%' }}
              animate={{ width: i === currentIdx ? '100%' : i < currentIdx ? '100%' : '0%' }}
              transition={i === currentIdx ? { duration: 5, ease: 'linear' } : { duration: 0 }}
            />
          </div>
        ))}
      </div>

      {/* Header */}
      <div className="flex items-center gap-2 px-4 py-2">
        <div className="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center">
          <span className="text-white text-xs font-bold">{group.author_name[0]?.toUpperCase()}</span>
        </div>
        <span className="text-white text-xs font-semibold flex-1">{group.author_name}</span>
        <span className="text-white/50 text-[10px]">{timeAgo(story.created_at)}</span>
        <button onClick={onClose} className="text-white ml-2"><X size={20} /></button>
      </div>

      {/* Content */}
      <div className="flex-1 relative flex items-center justify-center" onClick={(e) => {
        const rect = (e.target as HTMLElement).getBoundingClientRect()
        const x = e.clientX - rect.left
        if (x < rect.width / 2) goPrev()
        else goNext()
      }}>
        {story.image_url ? (
          <img src={story.image_url} alt="" className="max-w-full max-h-full object-contain" onError={(e) => {
            (e.target as HTMLImageElement).style.display = 'none'
          }} />
        ) : null}
      </div>
    </div>
  )
}

// ============================================================================
// DM LIST VIEW
// ============================================================================
function DMListView({ myCid, onChatTap }: {
  myCid: string
  onChatTap: (convo: InstapicDMConversation) => void
}) {
  const [convos, setConvos] = useState<InstapicDMConversation[]>([])

  const loadConvos = async () => {
    const data = await nuiFetch<InstapicDMConversation[]>('getInstapicDMList')
    if (Array.isArray(data)) setConvos(data)
  }

  useEffect(() => {
    loadConvos()
    // Refresh DM list when a new DM arrives in real-time
    const unsub = onNuiMessage('instapicDM', () => { loadConvos() })
    return () => unsub()
  }, [])

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center px-4 pt-2 pb-2 border-b border-white/5">
        <h2 className="text-white font-semibold text-sm">Messages</h2>
      </div>
      <div className="flex-1 overflow-y-auto">
        {convos.length === 0 && (
          <p className="text-white/30 text-center mt-12 text-sm">No conversations yet</p>
        )}
        {convos.map(c => (
          <button
            key={c.citizenid}
            onClick={() => onChatTap(c)}
            className="w-full flex items-center gap-3 px-4 py-3 hover:bg-white/5 transition-colors"
          >
            <div className="w-10 h-10 rounded-full bg-gradient-to-br from-pink-500 to-orange-400 flex items-center justify-center shrink-0">
              <span className="text-white text-sm font-bold">{c.username[0]?.toUpperCase()}</span>
            </div>
            <div className="flex-1 text-left min-w-0">
              <p className="text-white text-xs font-semibold">{c.username}</p>
              <p className="text-white/40 text-[11px] truncate">{c.last_message}</p>
            </div>
            <div className="flex flex-col items-end gap-1">
              <span className="text-white/30 text-[10px]">{timeAgo(c.last_message_at)}</span>
              {c.unread_count > 0 && (
                <div className="w-5 h-5 rounded-full bg-blue-500 flex items-center justify-center">
                  <span className="text-white text-[10px] font-bold">{c.unread_count}</span>
                </div>
              )}
            </div>
          </button>
        ))}
      </div>
    </div>
  )
}

// ============================================================================
// DM CHAT VIEW
// ============================================================================
function DMChatView({ otherCitizenid, otherUsername, myCid, onBack }: {
  otherCitizenid: string
  otherUsername?: string
  myCid: string
  onBack: () => void
}) {
  const [messages, setMessages] = useState<InstapicDM[]>([])
  const [text, setText] = useState('')
  const scrollRef = useRef<HTMLDivElement>(null)
  const [username, setUsername] = useState(otherUsername || '')

  useEffect(() => {
    (async () => {
      const data = await nuiFetch<InstapicDM[]>('getInstapicDMChat', { citizenid: otherCitizenid })
      if (Array.isArray(data)) setMessages(data)
      await nuiFetch('markInstapicDMsRead', { citizenid: otherCitizenid })
      if (!username) {
        const p = await nuiFetch<InstapicProfile>('getInstapicProfile', { citizenid: otherCitizenid })
        if (p?.username) setUsername(p.username)
      }
      setTimeout(() => scrollRef.current?.scrollTo(0, scrollRef.current.scrollHeight), 100)
    })()

    const unsub = onNuiMessage('instapicDM', (msg: any) => {
      const dm = msg?.data?.dm
      if (dm && (dm.sender_citizenid === otherCitizenid || dm.receiver_citizenid === otherCitizenid)) {
        setMessages(prev => [...prev, dm])
        nuiFetch('markInstapicDMsRead', { citizenid: otherCitizenid })
        setTimeout(() => scrollRef.current?.scrollTo(0, scrollRef.current.scrollHeight), 100)
      }
    })
    return () => unsub()
  }, [otherCitizenid])

  const sendDM = async () => {
    if (!text.trim()) return
    const dm = await nuiFetch<InstapicDM>('sendInstapicDM', { citizenid: otherCitizenid, message: text.trim() })
    if (dm) {
      setMessages(prev => [...prev, dm])
      setText('')
      soundManager.send()
      setTimeout(() => scrollRef.current?.scrollTo(0, scrollRef.current.scrollHeight), 100)
    }
  }

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center gap-2 px-4 pt-2 pb-2 border-b border-white/5">
        <button onClick={onBack} className="text-white"><ChevronLeft size={22} /></button>
        <div className="w-7 h-7 rounded-full bg-gradient-to-br from-pink-500 to-orange-400 flex items-center justify-center">
          <span className="text-white text-[10px] font-bold">{(username || '?')[0]?.toUpperCase()}</span>
        </div>
        <h2 className="text-white font-semibold text-sm">{username || 'Chat'}</h2>
      </div>
      <div ref={scrollRef} className="flex-1 overflow-y-auto px-4 py-2 space-y-2">
        {messages.map(m => {
          const isMine = m.sender_citizenid === myCid
          return (
            <div key={m.id} className={`flex ${isMine ? 'justify-end' : 'justify-start'}`}>
              <div className={`max-w-[75%] rounded-2xl px-3 py-2 ${isMine ? 'bg-blue-500 text-white' : 'bg-white/10 text-white'}`}>
                <p className="text-xs">{m.message}</p>
                <p className={`text-[9px] mt-0.5 ${isMine ? 'text-white/60' : 'text-white/30'}`}>{timeAgo(m.created_at)}</p>
              </div>
            </div>
          )
        })}
      </div>
      <div className="flex items-center gap-2 px-4 py-2 border-t border-white/5">
        <input
          type="text"
          value={text}
          onChange={e => setText(e.target.value.slice(0, 500))}
          onFocus={() => notifyTextFieldFocus(true)}
          onBlur={() => notifyTextFieldFocus(false)}
          placeholder="Message..."
          className="flex-1 bg-white/5 rounded-full px-4 py-2 text-white text-xs outline-none placeholder:text-white/30"
          onKeyDown={e => e.key === 'Enter' && sendDM()}
        />
        <button onClick={sendDM} disabled={!text.trim()} className="text-blue-400 disabled:opacity-30">
          <Send size={18} />
        </button>
      </div>
    </div>
  )
}

// ============================================================================
// SEARCH VIEW
// ============================================================================
function SearchView({ onBack, onProfileTap }: {
  onBack: () => void
  onProfileTap: (cid: string) => void
}) {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<InstapicProfile[]>([])
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  const doSearch = useCallback(async (q: string) => {
    if (!q.trim()) { setResults([]); return }
    const data = await nuiFetch<InstapicProfile[]>('searchInstapicUsers', { query: q.trim() })
    if (Array.isArray(data)) setResults(data)
  }, [])

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(() => doSearch(query), 300)
    return () => { if (debounceRef.current) clearTimeout(debounceRef.current) }
  }, [query])

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center gap-2 px-4 pt-2 pb-2 border-b border-white/5">
        <button onClick={onBack} className="text-white"><ChevronLeft size={22} /></button>
        <input
          type="text"
          value={query}
          onChange={e => setQuery(e.target.value)}
          onFocus={() => notifyTextFieldFocus(true)}
          onBlur={() => notifyTextFieldFocus(false)}
          placeholder="Search users..."
          className="flex-1 bg-white/10 rounded-lg px-3 py-2 text-white text-sm outline-none placeholder:text-white/40"
          autoFocus
        />
      </div>
      <div className="flex-1 overflow-y-auto">
        {results.map(u => (
          <button
            key={u.citizenid}
            onClick={() => onProfileTap(u.citizenid)}
            className="w-full flex items-center gap-3 px-4 py-3 hover:bg-white/5 transition-colors"
          >
            <div className="w-10 h-10 rounded-full bg-gradient-to-br from-pink-500 to-orange-400 flex items-center justify-center">
              <span className="text-white text-sm font-bold">{u.username[0]?.toUpperCase()}</span>
            </div>
            <div className="text-left">
              <p className="text-white text-xs font-semibold">{u.username}</p>
              {u.bio && <p className="text-white/40 text-[11px] line-clamp-1">{u.bio}</p>}
            </div>
          </button>
        ))}
        {query && results.length === 0 && (
          <p className="text-white/30 text-center mt-12 text-sm">No users found</p>
        )}
      </div>
    </div>
  )
}

// ============================================================================
// USER LIST VIEW (Followers / Following)
// ============================================================================
function UserListView({ title, citizenid, mode, myCid, onBack, onProfileTap }: {
  title: string
  citizenid: string
  mode: 'followers' | 'following'
  myCid: string
  onBack: () => void
  onProfileTap: (cid: string) => void
}) {
  const [users, setUsers] = useState<(InstapicProfile & { is_following?: boolean })[]>([])

  useEffect(() => {
    (async () => {
      const endpoint = mode === 'followers' ? 'getInstapicFollowers' : 'getInstapicFollowing'
      const data = await nuiFetch<any[]>(endpoint, { citizenid })
      if (Array.isArray(data)) setUsers(data)
    })()
  }, [citizenid, mode])

  const toggleFollow = async (targetCid: string) => {
    const res = await nuiFetch<{ following: boolean }>('toggleInstapicFollow', { citizenid: targetCid })
    if (res) {
      setUsers(prev => prev.map(u =>
        u.citizenid === targetCid ? { ...u, is_following: res.following } : u
      ))
    }
  }

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center px-4 pt-2 pb-2 border-b border-white/5">
        <button onClick={onBack} className="text-white mr-3"><ChevronLeft size={22} /></button>
        <h2 className="text-white font-semibold text-sm">{title}</h2>
      </div>
      <div className="flex-1 overflow-y-auto">
        {users.length === 0 && <p className="text-white/30 text-center mt-12 text-sm">No {title.toLowerCase()}</p>}
        {users.map(u => (
          <div key={u.citizenid} className="flex items-center gap-3 px-4 py-3">
            <button onClick={() => onProfileTap(u.citizenid)} className="w-10 h-10 rounded-full bg-gradient-to-br from-pink-500 to-orange-400 flex items-center justify-center shrink-0">
              <span className="text-white text-sm font-bold">{u.username[0]?.toUpperCase()}</span>
            </button>
            <button onClick={() => onProfileTap(u.citizenid)} className="flex-1 text-left min-w-0">
              <p className="text-white text-xs font-semibold">{u.username}</p>
            </button>
            {u.citizenid !== myCid && (
              <button
                onClick={() => toggleFollow(u.citizenid)}
                className={`px-3 py-1 rounded-lg text-[11px] font-medium ${u.is_following ? 'bg-white/10 text-white' : 'bg-blue-500 text-white'}`}
              >
                {u.is_following ? 'Following' : 'Follow'}
              </button>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}
