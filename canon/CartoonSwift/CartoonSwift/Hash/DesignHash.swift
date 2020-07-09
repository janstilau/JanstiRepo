//
//  DesignHash.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/6.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Design a HashSet without using any built-in hash table libraries.

 To be specific, your design should include these functions:

 add(value): Insert a value into the HashSet.
 contains(value) : Return whether the value exists in the HashSet or not.
 remove(value): Remove a value in the HashSet. If the value does not exist in the HashSet, do nothing.

 Example:

 MyHashSet hashSet = new MyHashSet();
 hashSet.add(1);
 hashSet.add(2);
 hashSet.contains(1);    // returns true
 hashSet.contains(3);    // returns false (not found)
 hashSet.add(2);
 hashSet.contains(2);    // returns true
 hashSet.remove(2);
 hashSet.contains(2);    // returns false (already removed)

 Note:

 All values will be in the range of [0, 1000000].
 The number of operations will be in the range of [1, 10000].
 Please do not use the built-in HashSet library.
 */

/*
 ["MyHashSet","add","add","add","remove","remove","contains","remove","remove","remove","contains","remove","add","add","add","add","contains","add","remove","contains","add","add","add","remove","add","add","add","contains","add","add","contains","add","contains","add","contains","remove","add","add","add","contains","remove","add","add","remove","contains","add","contains","add","add","add","contains","contains","remove","remove","contains","add","remove","remove","add","add","add","add","add","add","remove","add","add","contains","add","add","remove","contains","remove","add","remove","add","contains","remove","add","add","remove","contains","add","add","contains","add","add","add","add","contains","contains","add","contains","add","remove","remove","remove","add","contains","contains","add","add","add","remove","add","contains","contains","add","add","remove","contains","contains","remove","contains","add","add","remove","add","remove","add","add","contains","remove","contains","contains","contains","add","add","remove","contains","contains","add","add","contains","add","remove","add","remove","contains","contains","contains","add","contains","add","contains","add","add","contains","remove","contains","add","add","remove","add","contains","contains","remove","contains","add","add","add","add","add","remove","remove","add","add","add","remove","add","remove","contains","remove","add","add","contains","add","add","remove","add","remove","add","remove","add","add","contains","contains","remove","add","add","add","add","remove","contains","remove","add","add","add","add","add","contains","add","add","remove","add","remove","contains","remove","remove","add","add","contains","add","add","contains","remove","remove","add","add","contains","contains","add","contains","add","contains","add","remove","contains","add","add","add","remove","add","remove","add","contains","contains","add","contains","contains","remove","add","add","add","contains","add","add","add","add","add","add","contains","add","contains","add","add","add","add","add","add","add","add","add","add","add","add","contains","contains","add","add","remove","add","add","contains","contains","contains","contains","add","remove","add","contains","add","add","add","add","contains","add","add","add","add","contains","add","remove","remove","add","add","add","add","add","add","add","add","add","remove","add","contains","remove","add","add","add","add","add","add","remove","remove","add","remove","add","contains","contains","add","add","add","add","contains","add","add","add","contains","add","add","remove","add","remove","remove","contains","add","add","contains","add","remove","add","add","add","add","add","add","add","add","add","contains","add","remove","add","remove","remove","add","add","add","add","add","add","add","contains","add","add","remove","add","add","contains","add","contains","add","contains","remove","add","add","remove","add","add","add","remove","contains","add","add","add","contains","add","remove","remove","contains","add","add","contains","add","add","add","add","contains","remove","remove","contains","contains","add","add","contains","add","remove","remove","add","add","remove","remove","contains","add","remove","contains","contains","add","add","add","add","add","add","add","remove","add","remove","add","add","add","add","add","add","contains","add","add","add","add","contains","contains","contains","contains","contains","contains","add","add","add","add","add","add","contains","add","add","remove","contains","add","contains","contains","add","add","contains","remove","add","remove","contains","add","remove","remove","contains","add","contains","contains","add","add","add","add","remove","add","add","contains","add","add","add","add","add","add","add","contains","add","contains","add","contains","add","contains","add","add","remove","add","contains","add","contains","add","add","add","remove","add","remove","add","add","add","add","contains","add","remove","add","remove","contains","add","add","add","add","contains","add","add","add","add","contains","add","add","remove","contains","add","contains","add","contains","remove","add","add","add","add","contains","add","remove","contains","remove","remove","add","add","remove","add","add","remove","remove","remove","remove","add","remove","remove","add","contains","remove","remove","add","contains","add","add","contains","contains","add","add","add","add","add","add","add","remove","contains","contains","remove","add","contains","contains","contains","add","add","remove","add","add","add","contains","contains","contains","add","add","contains","add","add","contains","add","remove","add","remove","remove","remove","add","add","add","add","add","add","add","add","remove","add","remove","add","contains","add","add","remove","contains","add","add","add","add","add","add","add","add","remove","add","remove","contains","remove","remove","remove","add","add","contains","add","add","contains","add","contains","remove","contains","add","add","remove","add","add","add","remove","add","remove","add","add","contains","remove","add","add","add","add","add","add","contains","contains","add","contains","remove","add","add","contains","remove","remove","add","contains","remove","add","add","contains","contains","add","add","add","add","remove","remove","contains","add","contains","add","add","add","contains","contains","add","remove","contains","contains","add","add","add","add","add","add","contains","add","add","add","add","remove","add","add","add","contains","add","add","remove","contains","add","add","add","add","contains","remove","add","remove","remove","remove","add","add","add","add","add","add","add","contains","add","add","add","contains","add","add","remove","contains","remove","add","remove","contains","contains","contains","add","remove","add","remove","add","remove","add","add","add","remove","remove","remove","contains","add","add","remove","contains","remove","add","remove","add","remove","add","add","add","remove","add","add","add","remove","add","remove","add","contains","add","contains","add","add","contains","add","remove","remove","contains","remove","remove","add","remove","add","add","add","add","remove","add","contains","add","add","remove","add","contains","contains","add","add","add","add","remove","add","add","remove","add","add","add","remove","add","add","remove","contains","add","add","add","add","add","contains","remove","add","remove","remove","add","contains","add","add","add","contains","add","add","add","add","add","add","add","add","contains","remove","remove","add","add","add","contains","contains","remove","add","add","add","contains","contains","add","contains","add","contains","remove","add","contains","remove","add","contains","add","add","add","add","remove","add","contains","add","add","add","add","add","add","add","remove","contains","add","add","add","add","add","add","add","add","add","add","contains","add","remove","remove","remove","remove","add","add","contains","add","remove","add","add","add","add","add","contains","contains","add","add","add","add","add","remove","add","remove","contains","add","add","add","add","add","add","remove","contains","add","add","contains","remove","add","contains","add","remove","contains","add","add","remove","remove","contains","remove","add","add","remove","remove","add","add","add","remove","add","add","add","add","add","add","add","remove","remove","add","add","remove","remove","remove","add","contains","contains","add","contains","contains","add","add","contains","add","remove","remove","add","add","add","add","contains","add","add","add","add","remove","contains","add","add","add"]
 [[],[614],[104],[991],[895],[255],[614],[586],[411],[425],[104],[291],[869],[708],[148],[580],[184],[887],[83],[798],[677],[919],[211],[564],[630],[250],[874],[991],[387],[809],[739],[580],[723],[32],[108],[315],[37],[956],[587],[863],[405],[997],[447],[716],[377],[543],[32],[974],[763],[647],[163],[974],[527],[182],[499],[316],[352],[690],[896],[341],[67],[714],[953],[320],[134],[509],[146],[591],[388],[816],[7],[879],[168],[579],[171],[631],[578],[35],[271],[95],[747],[278],[543],[894],[320],[929],[396],[835],[304],[919],[552],[725],[250],[266],[279],[39],[82],[681],[104],[250],[934],[924],[298],[883],[627],[266],[934],[483],[887],[653],[705],[708],[757],[304],[32],[149],[501],[521],[972],[692],[796],[304],[816],[631],[562],[816],[207],[199],[875],[616],[767],[97],[218],[397],[671],[610],[35],[113],[543],[290],[708],[807],[386],[675],[37],[887],[417],[306],[434],[519],[633],[308],[508],[941],[511],[67],[575],[79],[219],[933],[288],[7],[962],[507],[235],[856],[77],[280],[701],[130],[498],[199],[173],[319],[319],[647],[361],[942],[143],[334],[924],[208],[258],[681],[187],[35],[183],[534],[694],[685],[432],[911],[727],[217],[395],[940],[246],[489],[101],[926],[45],[234],[692],[555],[280],[896],[681],[144],[635],[116],[21],[985],[106],[705],[879],[396],[407],[406],[470],[309],[88],[602],[38],[222],[186],[309],[284],[578],[993],[451],[859],[687],[724],[967],[881],[334],[470],[240],[761],[21],[98],[219],[300],[922],[678],[453],[306],[924],[346],[753],[656],[623],[148],[218],[656],[231],[346],[712],[602],[828],[646],[602],[77],[625],[788],[76],[187],[266],[53],[132],[566],[556],[555],[658],[887],[483],[46],[400],[104],[651],[846],[405],[767],[463],[88],[746],[457],[259],[592],[792],[705],[641],[70],[703],[848],[562],[657],[506],[936],[93],[716],[88],[472],[285],[2],[308],[6],[838],[141],[234],[947],[959],[174],[207],[780],[475],[521],[756],[997],[675],[193],[99],[371],[220],[370],[806],[627],[892],[922],[845],[780],[797],[546],[218],[652],[544],[51],[452],[940],[292],[211],[546],[905],[755],[392],[286],[588],[780],[668],[609],[756],[762],[956],[877],[299],[936],[385],[608],[611],[482],[324],[831],[1],[831],[145],[384],[552],[586],[543],[772],[481],[614],[652],[828],[757],[758],[542],[923],[513],[706],[739],[239],[272],[497],[345],[148],[831],[615],[455],[382],[73],[404],[576],[483],[744],[819],[384],[775],[116],[18],[439],[916],[489],[729],[466],[455],[778],[850],[52],[17],[137],[160],[826],[806],[735],[346],[395],[308],[416],[430],[443],[396],[897],[18],[212],[798],[95],[165],[839],[954],[996],[262],[970],[727],[349],[174],[719],[98],[352],[459],[331],[689],[51],[309],[792],[319],[33],[876],[794],[654],[16],[957],[45],[19],[742],[211],[153],[131],[21],[287],[442],[119],[363],[425],[513],[384],[730],[448],[700],[482],[187],[472],[303],[109],[997],[423],[328],[152],[641],[178],[146],[349],[194],[539],[413],[795],[161],[687],[896],[795],[340],[497],[392],[745],[792],[578],[861],[152],[955],[647],[605],[440],[238],[877],[493],[205],[425],[116],[282],[29],[441],[601],[727],[401],[863],[461],[569],[787],[72],[972],[274],[858],[947],[940],[579],[373],[67],[694],[355],[542],[187],[835],[169],[529],[8],[950],[293],[5],[512],[90],[341],[60],[977],[348],[763],[728],[288],[130],[501],[228],[987],[481],[62],[837],[599],[623],[616],[853],[258],[90],[405],[704],[598],[444],[443],[232],[898],[539],[164],[623],[422],[583],[127],[893],[528],[95],[991],[807],[685],[523],[221],[366],[417],[695],[276],[303],[821],[839],[505],[955],[588],[442],[627],[112],[170],[970],[602],[169],[43],[568],[572],[135],[843],[887],[172],[406],[973],[175],[644],[505],[373],[579],[932],[588],[450],[572],[612],[121],[377],[180],[434],[506],[288],[244],[533],[17],[676],[636],[511],[287],[595],[258],[696],[481],[42],[667],[464],[222],[232],[29],[151],[429],[257],[67],[348],[762],[594],[956],[765],[724],[620],[413],[730],[914],[217],[378],[893],[779],[240],[868],[547],[730],[215],[898],[907],[309],[856],[968],[869],[471],[695],[145],[573],[605],[713],[566],[976],[846],[660],[335],[77],[18],[671],[889],[428],[721],[483],[553],[865],[632],[898],[596],[418],[220],[338],[509],[694],[299],[790],[488],[33],[348],[819],[512],[81],[41],[994],[413],[689],[783],[377],[860],[0],[650],[174],[960],[493],[343],[203],[316],[896],[762],[290],[694],[71],[424],[283],[711],[159],[14],[74],[9],[418],[513],[94],[846],[450],[232],[716],[829],[639],[374],[683],[709],[597],[476],[932],[895],[981],[785],[495],[392],[546],[908],[715],[203],[60],[657],[720],[168],[886],[356],[382],[728],[794],[940],[498],[725],[9],[146],[616],[254],[78],[839],[243],[662],[517],[565],[946],[370],[539],[563],[970],[693],[520],[813],[585],[148],[217],[707],[942],[405],[239],[839],[116],[627],[389],[855],[15],[811],[804],[0],[490],[527],[822],[613],[527],[633],[383],[93],[410],[815],[592],[895],[57],[21],[425],[630],[838],[465],[251],[905],[95],[909],[270],[346],[690],[134],[5],[401],[412],[812],[329],[143],[586],[459],[375],[326],[495],[237],[552],[448],[298],[13],[676],[342],[200],[822],[796],[219],[309],[960],[166],[734],[115],[930],[132],[247],[406],[765],[927],[267],[806],[823],[359],[180],[234],[376],[264],[104],[928],[853],[624],[500],[909],[470],[795],[531],[607],[238],[316],[962],[459],[200],[348],[240],[521],[801],[589],[412],[405],[964],[676],[833],[29],[768],[292],[904],[978],[616],[659],[681],[704],[845],[173],[553],[958],[594],[167],[831],[808],[35],[154],[324],[492],[536],[439],[360],[92],[917],[815],[722],[660],[160],[302],[454],[479],[289],[40],[222],[169],[331],[312],[817],[35],[6],[752],[894],[321],[451],[8],[453],[518],[940],[121],[627],[932],[522],[67],[188],[380],[651],[19],[519],[945],[860],[103],[175],[212],[415],[738],[603],[437],[898],[751],[487],[934],[387],[859],[592],[961],[345],[363],[671],[714],[782],[231],[389],[900],[522],[789],[59],[115],[639],[663],[32],[786],[570],[307],[42],[118],[779],[787],[592],[921],[374],[738],[947],[961],[364],[179]]
 */

class MyHashSet {

    let loadFactor: Double = 1
    var buckets: [ListNode]
    var nodeCount: Int
    
    init() {
        buckets = [ListNode](repeating: ListNode(-1), count: 20)
        nodeCount = 0
    }
    
    func add(_ key: Int) {
        expandIfNeeded()
        let bucketIdx = key % buckets.count
        let bucketNode = buckets[bucketIdx]
        var current = bucketNode
        while current.next != nil {
            current = current.next!
            if (current.val == key) { return }
        }
        let newNode = ListNode(key)
        current.next = newNode
        nodeCount += 1
    }
    
    func remove(_ key: Int) {
        let bucketIdx = key % buckets.count
        let bucketNode = buckets[bucketIdx]
        var current = bucketNode
        while current.next != nil {
            if current.next!.val == key {
                current.next = current.next?.next
                nodeCount -= 1
                return
            }
            current = current.next!
        }
    }
    
    func expandIfNeeded() {
        let maxCount = Double(buckets.count) * loadFactor
        guard Double(nodeCount) > maxCount else {
            return
        }
        let newBucket = [ListNode](repeating: ListNode(-1), count: buckets.capacity * 2)
        let stashBuckets = buckets
        buckets = newBucket
        nodeCount = 0
        for aList in stashBuckets {
            var currentNode = aList.next
            while currentNode != nil {
                add(currentNode!.val)
                currentNode = currentNode?.next
            }
        }
    }
    
    /** Returns true if this set contains the specified element */
    func contains(_ key: Int) -> Bool {
        let bucketIdx = key % buckets.count
        let bucketNode = buckets[bucketIdx]
        var currentNode = bucketNode.next
        while currentNode != nil {
            if currentNode!.val == key { return true }
            currentNode = currentNode?.next
        }
        return false
    }
}

/*
 class MyHashSet {
   private Bucket[] bucketArray;
   private int keyRange;

   /** Initialize your data structure here. */
   public MyHashSet() {
     this.keyRange = 769;
     this.bucketArray = new Bucket[this.keyRange];
     for (int i = 0; i < this.keyRange; ++i)
       this.bucketArray[i] = new Bucket();
   }

   protected int _hash(int key) {
     return (key % this.keyRange);
   }

   public void add(int key) {
     int bucketIndex = this._hash(key);
     this.bucketArray[bucketIndex].insert(key);
   }

   public void remove(int key) {
     int bucketIndex = this._hash(key);
     this.bucketArray[bucketIndex].delete(key);
   }

   /** Returns true if this set contains the specified element */
   public boolean contains(int key) {
     int bucketIndex = this._hash(key);
     return this.bucketArray[bucketIndex].exists(key);
   }
 }

 class Node {
    private int key;
    private int value;
    public Node(int key, int value) {
        this.key = key;
        this.value = value;
    }
 }
 class Bucket {
   private LinkedList<Node> container;

   public Bucket() {
     container = new LinkedList<Node>();
   }

   public void insert(Integer key) {
     int index = this.container.indexOf(key);
     if (index == -1) {
       this.container.addFirst(key);
     }
   }
 
 /** value will always be non-negative. */
    public void put(int key, int value) {

    }

   public void delete(Integer key) {
     this.container.remove(key);
   }

   public boolean exists(Integer key) {
     int index = this.container.indexOf(key);
     return (index != -1);
   }
 }

 虽然, 不可以用内置的 hash set, 但是可以用 LinkedList 这种数据结构, 系统内建的类库, 能用还是要用.
 */

/*
 class Pair<U, V> {
   public U first;
   public V second;

   public Pair(U first, V second) {
     this.first = first;
     this.second = second;
   }
 }


 class Bucket {
   private List<Pair<Integer, Integer>> bucket;

   public Bucket() {
     this.bucket = new LinkedList<Pair<Integer, Integer>>();
   }

   public Integer get(Integer key) {
     for (Pair<Integer, Integer> pair : this.bucket) {
       if (pair.first.equals(key))
         return pair.second;
     }
     return -1;
   }

   public void update(Integer key, Integer value) {
     boolean found = false;
     for (Pair<Integer, Integer> pair : this.bucket) {
       if (pair.first.equals(key)) {
         pair.second = value;
         found = true;
       }
     }
     if (!found)
       this.bucket.add(new Pair<Integer, Integer>(key, value));
   }

   public void remove(Integer key) {
     for (Pair<Integer, Integer> pair : this.bucket) {
       if (pair.first.equals(key)) {
         this.bucket.remove(pair);
         break;
       }
     }
   }
 }

 class MyHashMap {
   private int key_space;
   private List<Bucket> hash_table;

   /** Initialize your data structure here. */
   public MyHashMap() {
     this.key_space = 2069;
     this.hash_table = new ArrayList<Bucket>();
     for (int i = 0; i < this.key_space; ++i) {
       this.hash_table.add(new Bucket());
     }
   }

   /** value will always be non-negative. */
   public void put(int key, int value) {
     int hash_key = key % this.key_space;
     this.hash_table.get(hash_key).update(key, value);
   }

   /**
    * Returns the value to which the specified key is mapped, or -1 if this map contains no mapping
    * for the key
    */
   public int get(int key) {
     int hash_key = key % this.key_space;
     return this.hash_table.get(hash_key).get(key);
   }

   /** Removes the mapping of the specified value key if this map contains a mapping for the key */
   public void remove(int key) {
     int hash_key = key % this.key_space;
     this.hash_table.get(hash_key).remove(key);
   }
 }

 /**
  * Your MyHashMap object will be instantiated and called as such: MyHashMap obj = new MyHashMap();
  * obj.put(key,value); int param_2 = obj.get(key); obj.remove(key);
  */

 作者：LeetCode
 链接：https://leetcode-cn.com/problems/design-hashmap/solution/she-ji-ha-xi-biao-by-leetcode/
 来源：力扣（LeetCode）
 著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。
 */

/**
 * Your MyHashSet object will be instantiated and called as such:
 * let obj = MyHashSet()
 * obj.add(key)
 * obj.remove(key)
 * let ret_3: Bool = obj.contains(key)
 */
