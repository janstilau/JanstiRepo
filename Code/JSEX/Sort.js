// 冒泡排序的时候, 两个循环的走向是相反的.
function bubbleSort(array, sortFunc) {
    if (!Array.isArray(array)) { return; }
    if (array.length <= 1) { return; } 
    for(let i = 0; i < array.length; ++i) {
        let hasSwapped = false;
        for(let j = array.length - 1; j > i; --j) {
            let preIdx = j-1;
            let currentIdx = j;
            if (sortFunc) {
                if (sortFunc(array[preIdx], array[currentIdx]) > 0) {
                    [array[preIdx], array[currentIdx]] = [array[currentIdx], array[preIdx]]
                    hasSwapped = true;
                }
            } else {
                if (array[preIdx] > array[currentIdx]) {
                    [array[preIdx], array[currentIdx]] = [array[currentIdx], array[preIdx]]
                    console.log(array)
                    hasSwapped = true;
                }
            }
        }
        if (!hasSwapped) { return; }
    }
}

function selectSort(array) {
    if (!Array.isArray(array)) { return; }
    if (array.length <= 1) { return; }
    for(let i = 0; i < array.length; ++i) {
        let minIndex = i;
        let minElement = array[minIndex];
        for (let j = i+1; j < array.length; j++) {
            const element = array[j]; // vscode 给出的代码片段用的 const, 尽量多用 const.
            if (minElement > element) {
                minIndex = j;
                minElement = element;
            }
        }
        if (minIndex != i) {
            [array[i], array[minIndex]] = [array[minIndex], array[i]]
        }
    }
}

function insetSort(array) {
    if (!Array.isArray(array)) { return; }
    if (array.length <= 0) { return; }
    for (let i = 1; i < array.length; ++i) {
        const element = array[i];
        for (let j = 0; j < i; ++j) {
            if (array[j] > element) {
                let insertIndex = j;
                for (let z = i; z > insertIndex; --z) {
                    array[z] = array[z-1];
                }
                array[insertIndex] = element;
                break;
            }
        }
    }
}

function mergeSort(array) {
    if (!Array.isArray(array)) { return; }
    if (array.length <= 1) { return; }
    const mergeArray = new Array(array.length);
    mergeSortImp(array, mergeArray, 0, array.length-1);
}

function mergeSortImp(sourceArray, mergeArray, left, right) {
    if (left >= right) { return; }
    
    let mid = Math.floor(left + (right-left) * 0.5);
    mergeSortImp(sourceArray, mergeArray, left, mid);
    mergeSortImp(sourceArray, mergeArray, mid+1, right);
    merge(sourceArray, mergeArray, left, mid, mid+1, right);
}

function merge(sourceArray, mergeArray, left, leftEnd, rightStart, right) {
    let mergeIndex = left;
    let leftIndex = left;
    let rightIndex = rightStart;
    for (; 
        leftIndex <= leftEnd && rightIndex <= right;
        mergeIndex += 1) {
            if (sourceArray[leftIndex] <= sourceArray[rightIndex]) {
                mergeArray[mergeIndex] = sourceArray[leftIndex];
                leftIndex += 1;
            } else {
                mergeArray[mergeIndex] = sourceArray[rightIndex];
                rightIndex += 1;
            }
    }
    while(leftIndex <= leftEnd) {
        mergeArray[mergeIndex] = sourceArray[leftIndex];
        mergeIndex += 1;
        leftIndex += 1;
    }
    while(rightIndex <= right) {
        mergeArray[mergeIndex] = sourceArray[rightIndex];
        mergeIndex += 1;
        rightIndex += 1;
    }
    for (let moveIndex = left; moveIndex <= right; moveIndex += 1) {
        sourceArray[moveIndex] = mergeArray[moveIndex]
    }
    console.log(sourceArray)
}

function quickSort(array) {
    
}


function main() {
    let data_1 = [100, 5, 12, 7, 23, 15, 4, 85, 9856, -2, 6, -21];
    let data_2 = [];
    let data_3 = [];
    let data_4 = [];
    let data_5 = [];
    let data_6 = [];
    let data_7 = [];
    let data_8 = [];
    let data_9 = [];
    console.log('original ' + data_1);
    mergeSort(data_1);
    console.log('after    ' + data_1);
}

main();


